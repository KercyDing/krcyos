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

test "LogQueue push/pop" {
    const capacity = 1024;
    const Queue = LogQueue(capacity);
    var queue = Queue.init();

    const record: LogRecord = .{
        .level = .debug,
        .timestamp = 20260529015300,
        .length = 0,
        .msg = undefined,
    };

    try std.testing.expectEqual(null, queue.pop());
    try std.testing.expect(queue.tryPush(record));

    const popped = queue.pop() orelse return error.TestExpectedRecord;
    try std.testing.expectEqual(record.level, popped.level);
    try std.testing.expectEqual(record.timestamp, popped.timestamp);

    try std.testing.expectEqual(null, queue.pop());
}
