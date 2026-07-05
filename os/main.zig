const std = @import("std");
const config = @import("config");
const banner = @import("banner.zig");

const arch = @import("arch");
const lib = @import("lib");
const mm = @import("mm");
const task = @import("task");
const user = @import("user");
const super_tests = @import("super_tests.zig");

// Bare metal environment and stack
extern var sbss: u8;
extern var ebss: u8;
extern var boot_stack_top: u8;

// Entry point
export fn _start() linksection(".text.entry") callconv(.naked) noreturn {
    asm volatile (
        \\la sp, boot_stack_top
        \\call main
    );
    while (true) {}
}

// Kernel main function
export fn main() noreturn {
    clearBss();
    arch.trap.init();
    mm.init();
    lib.uart.init();
    banner.show();

    switch (config.mode) {
        .super => {
            arch.timer.init();
            task.scheduler.init(@intFromPtr(&boot_stack_top));

            super_tests.testAll();
            lib.drainLogs();

            task.scheduler.schedule();

            @panic("Super Mode Returned Unexpectedly!");
        },
        .user => {
            lib.info("Entering user mode...", .{});
            lib.drainLogs();
            user.enterUser();

            @panic("User Mode Returned Unexpectedly!");
        },
    }
}

fn clearBss() void {
    const start_bss = @intFromPtr(&sbss);
    const end_bss = @intFromPtr(&ebss);
    const length = end_bss - start_bss;

    const bss: [*]u8 = @ptrCast(&sbss);
    @memset(bss[0..length], 0);
}

/// Panic handler
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = error_return_trace;
    _ = ret_addr;

    lib.err("======== KERNEL PANIC ========", .{});
    lib.err("{s}", .{msg});
    lib.err("==============================", .{});
    lib.drainLogs();

    asm volatile ("csrc sstatus, 2"); // Turn off global interrupts
    arch.wfi();
}
