const std = @import("std");

const config = @import("config");
const constants = @import("constants");
const abi = @import("abi");
const arch = @import("arch");
const lib = @import("lib");
const mm = @import("mm");
const task = @import("task");
const user = @import("user");
const trap = @import("trap");

const banner = @import("banner.zig");
const super_tests = @import("super_tests.zig");

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
    trap.init();
    mm.init();
    lib.uart.init();
    banner.show();

    switch (config.mode) {
        .super => {
            arch.timer.init(constants.TIMER_TICKS_PER_MS * 50);
            task.scheduler.init(@intFromPtr(&abi.linker.boot_stack_top));

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
    const start_bss = @intFromPtr(&abi.linker.sbss);
    const end_bss = @intFromPtr(&abi.linker.ebss);
    const length = end_bss - start_bss;

    const bss: [*]u8 = @ptrCast(&abi.linker.sbss);
    @memset(bss[0..length], 0);
}

/// Custom panic handler
pub const panic = std.debug.FullPanic(myPanic);

fn myPanic(msg: []const u8, first_trace_addr: ?usize) noreturn {
    _ = first_trace_addr;

    // Interrupts off first,
    // a timer tick could reschedule from panic context.
    arch.disableInterrupts();

    lib.err("======== KERNEL PANIC ========", .{});
    lib.err("{s}", .{msg});
    lib.err("==============================", .{});
    lib.drainLogs();

    arch.halt();
}
