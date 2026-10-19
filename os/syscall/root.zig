//! os/syscall/root.zig

const abi = @import("abi");
const lib = @import("lib");
const arch = @import("arch");
const user = @import("user");

const csr = arch.csr;

const SSTATUS_SUM: usize = @as(usize, 1) << 18;

pub fn handle(frame: *abi.TrapFrame) void {
    switch (frame.a7) {
        abi.syscall.SYS_EXIT => {
            lib.info("User task exited.", .{});
            lib.drainLogs();
            @panic("User Mode Ended.");
        },

        abi.syscall.SYS_WRITE => {
            const fd = frame.a0;
            const user_buf = frame.a1;
            const len = frame.a2;

            const written = handleSysWrite(fd, user_buf, len) catch |err| {
                lib.err("SYS_WRITE failed: {}", .{err});
                lib.drainLogs();

                frame.a0 = abi.syscall.RET_ERR;
                frame.sepc += 4;
                return;
            };

            frame.a0 = written;
            frame.sepc += 4;
        },

        abi.syscall.SYS_READ => {
            lib.info("User task reading...", .{});
            lib.drainLogs();

            frame.a0 = 0;
            frame.sepc += 4;
        },

        else => {
            lib.err("Unknown syscall: {}", .{frame.a7});
            lib.drainLogs();
            @panic("Unknown user syscall.");
        },
    }
}

fn handleSysWrite(fd: usize, user_buf: usize, len: usize) !usize {
    switch (fd) {
        1, 2 => {},
        else => return error.BadFileDescriptor,
    }

    if (len == 0) return 0;

    if (!user.isUserRange(user_buf, len)) return error.BadUserPointer;

    const old_sstatus = csr.read(.sstatus);
    csr.write(.sstatus, old_sstatus | SSTATUS_SUM);
    defer csr.write(.sstatus, old_sstatus);

    const ptr: [*]const u8 = @ptrFromInt(user_buf);
    lib.console.writeBytes(ptr[0..len]);

    return len;
}
