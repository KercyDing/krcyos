const std = @import("std");

pub fn SPSCQueue(comptime T: type, comptime capacity: usize) type {
    if (!std.math.isPowerOfTwo(capacity)) {
        @compileError("Capacity must be the power of 2!");
    }

    return struct {
        buffer: [capacity]T = undefined,
        head: usize = 0,
        tail: usize = 0,

        pub fn init() @This() {
            return .{};
        }

        pub fn push(self: *@This(), data: T) bool {
            const curr_tail = @atomicLoad(usize, &self.tail, .monotonic);
            const curr_head = @atomicLoad(usize, &self.head, .acquire);

            if (curr_tail -% curr_head == capacity) return false;
            self.buffer[curr_tail & (capacity - 1)] = data; // equal to `curr_tail % capacity`

            @atomicStore(usize, &self.tail, curr_tail +% 1, .release); // tail + 1

            return true;
        }

        pub fn pop(self: *@This()) ?T {
            const curr_head = @atomicLoad(usize, &self.head, .monotonic);
            const curr_tail = @atomicLoad(usize, &self.tail, .acquire);

            if (curr_head == curr_tail) return null;

            const data = self.buffer[curr_head & (capacity - 1)];
            @atomicStore(usize, &self.head, curr_head +% 1, .release); // head + 1

            return data;
        }
    };
}

test "SPSCQueue concurrent push/pop" {
    const capacity = 1024;
    const Queue = SPSCQueue(usize, capacity);
    var queue = Queue.init();

    const num_items = 1_000_000;

    const producer = struct {
        fn run(q: *Queue) void {
            var i: usize = 1;
            while (i <= num_items) : (i += 1) {
                while (!q.push(i)) {
                    std.atomic.spinLoopHint();
                }
            }
        }
    }.run;

    const consumer = struct {
        fn run(q: *Queue, out_sum: *usize) void {
            var sum: usize = 0;
            var count: usize = 0;
            while (count < num_items) {
                if (q.pop()) |val| {
                    sum += val;
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

    const expected_num = (1 + num_items) * num_items / 2;

    try std.testing.expectEqual(expected_num, total_sum);
}
