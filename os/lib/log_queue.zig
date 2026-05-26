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
            const queue = .{};
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

        pub fn pop() ?LogRecord {}
    };
}
