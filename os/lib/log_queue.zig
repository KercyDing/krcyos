const std = @import("std");
const LogRecord = @import("log_record.zig").LogRecord;

pub fn LogQueue(comptime capacity: usize) type {
    if (!std.math.isPowerOfTwo(capacity)) {
        @compileError("Capacity must be the power of 2!");
    }

    return struct {
        const Slot = struct {
            seq: usize,
            data: LogRecord,
        };

        buffer: [capacity]Slot = undefined,
        head: usize = 0,
        tail: usize = 0,

        pub fn init() @This() {
            var queue: @This() = .{};
            for (0..capacity) |i| {
                queue.buffer[i].seq = i;
            }

            return queue;
        }

        pub fn tryPush(self: *@This(), record: LogRecord) bool {
            while (true) {
                const tail = @atomicLoad(usize, &self.tail, .monotonic);
                const tail_slot = &self.buffer[tail & (capacity - 1)];
                const tail_seq = @atomicLoad(usize, &tail_slot.seq, .acquire);

                switch (std.math.order(tail_seq, tail)) { // seq order check
                    .eq => {
                        // CAS:
                        // Check if `self.tail` equals to `tail`.
                        // Return `null` if succeed.
                        const result = @cmpxchgWeak(
                            usize,
                            &self.tail,
                            tail,
                            tail +% 1,
                            .acq_rel,
                            .monotonic,
                        );

                        if (result == null) { // CAS succeed
                            tail_slot.data = record;
                            @atomicStore(usize, &tail_slot.seq, tail +% 1, .release);

                            return true;
                        }
                    },
                    .lt => return false, // queue full
                    .gt => continue,
                }
            }
        }

        pub fn pop(self: *@This()) ?LogRecord {
            const head = self.head;
            const head_slot = &self.buffer[head & (capacity - 1)];
            const head_seq = @atomicLoad(usize, &head_slot.seq, .acquire);

            if (head_seq != head +% 1) return null;

            const record = head_slot.data;

            self.head = head +% 1;
            @atomicStore(usize, &head_slot.seq, head +% capacity, .release);

            return record;
        }
    };
}

test "LogQueue push/pop minimum" {
    const capacity = 1024;
    const Queue = LogQueue(capacity);
    var queue = Queue.init();

    const record: LogRecord = .{
        .level = .debug,
        .length = 0,
        .timestamp = 20260529015300,
        .msg = undefined,
    };

    try std.testing.expectEqual(null, queue.pop()); // pop null
    try std.testing.expect(queue.tryPush(record));

    const popped = queue.pop() orelse return error.TestExpectedRecord;
    try std.testing.expectEqual(record.level, popped.level);
    try std.testing.expectEqual(record.timestamp, popped.timestamp);

    try std.testing.expectEqual(null, queue.pop()); // empty
}

test "LogQueue full and reuse" {
    const Queue = LogQueue(4);
    var queue = Queue.init();

    for (1..5) |i| {
        const record_i: LogRecord = .{
            .level = .debug,
            .length = 0,
            .timestamp = i,
            .msg = undefined,
        };
        try std.testing.expect(queue.tryPush(record_i)); // 1..4
    }

    const record_5: LogRecord = .{
        .level = .debug,
        .length = 0,
        .timestamp = 5,
        .msg = undefined,
    };

    try std.testing.expect(!queue.tryPush(record_5)); // false
    const popped_1 = queue.pop() orelse return error.TestExpectedRecord;
    try std.testing.expectEqual(@as(usize, 1), popped_1.timestamp);

    try std.testing.expect(queue.tryPush(record_5)); // true

    for (2..6) |i| {
        const popped = queue.pop() orelse return error.TestExpectedRecord;
        try std.testing.expectEqual(@as(usize, i), popped.timestamp);
    }

    try std.testing.expectEqual(null, queue.pop()); // empty
}

test "LogQueue SPSC push/pop" {
    const capacity = 1024;
    const Queue = LogQueue(capacity);
    var queue = Queue.init();

    const num_items = 1_000_000;

    const producer = struct {
        fn run(q: *Queue) void {
            var i: usize = 1;
            while (i <= num_items) : (i += 1) {
                const record: LogRecord = .{
                    .level = .debug,
                    .length = 0,
                    .timestamp = i,
                    .msg = undefined,
                };
                while (!q.tryPush(record)) {
                    std.atomic.spinLoopHint();
                }
            }
        }
    }.run;

    const consumer = struct {
        fn run(q: *Queue, out_sum: *usize) void {
            var count: usize = 0;
            var sum: usize = 0;
            while (count < num_items) {
                if (q.pop()) |record| {
                    sum += record.timestamp;
                    count += 1;
                } else {
                    std.atomic.spinLoopHint();
                }
            }
            out_sum.* = sum;
        }
    }.run;

    var total_sum: usize = 0;

    const p_thread = try std.Thread.spawn(.{}, producer, .{&queue});
    const c_thread = try std.Thread.spawn(.{}, consumer, .{ &queue, &total_sum });

    p_thread.join();
    c_thread.join();

    const expected_sum = (1 + num_items) * num_items / 2;

    try std.testing.expectEqual(expected_sum, total_sum);
}

test "LogQueue MPSC push/pop" {
    const capacity = 4;
    const Queue = LogQueue(capacity);
    var queue = Queue.init();

    const producer_count = 4;
    const items_per_producer = 10_000;
    const total_items = producer_count * items_per_producer;

    const producer = struct {
        fn run(q: *Queue, producer_id: usize) void {
            var i: usize = 1;

            while (i <= items_per_producer) : (i += 1) {
                const value = producer_id * items_per_producer + i;

                const record: LogRecord = .{
                    .level = .debug,
                    .length = 0,
                    .timestamp = value,
                    .msg = undefined,
                };

                while (!q.tryPush(record)) {
                    std.atomic.spinLoopHint();
                }
            }
        }
    }.run;

    const consumer = struct {
        fn run(q: *Queue, out_sum: *usize) void {
            var count: usize = 0;
            var sum: usize = 0;

            while (count < total_items) {
                if (q.pop()) |record| {
                    sum += record.timestamp;
                    count += 1;
                } else {
                    std.atomic.spinLoopHint();
                }
            }

            out_sum.* = sum;
        }
    }.run;

    var total_sum: usize = 0;

    const c_thread = try std.Thread.spawn(.{}, consumer, .{ &queue, &total_sum });

    const p0 = try std.Thread.spawn(.{}, producer, .{ &queue, 0 });
    const p1 = try std.Thread.spawn(.{}, producer, .{ &queue, 1 });
    const p2 = try std.Thread.spawn(.{}, producer, .{ &queue, 2 });
    const p3 = try std.Thread.spawn(.{}, producer, .{ &queue, 3 });

    p0.join();
    p1.join();
    p2.join();
    p3.join();
    c_thread.join();

    const expected_sum = (1 + total_items) * total_items / 2;

    try std.testing.expectEqual(expected_sum, total_sum);
}
