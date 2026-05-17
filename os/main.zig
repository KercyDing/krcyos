const std = @import("std");
const config = @import("config");
const log = @import("lib").log;
const banner = @import("banner.zig");

const arch = @import("arch");
const mm = @import("mm");
const lib = @import("lib");
const tests = @import("tests.zig");

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

    if (config.tests) tests.testAll();

    arch.timer.init();

    enableWFIMode();
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

    log.err("======== KERNEL PANIC ========", .{});
    log.err("{s}", .{msg});
    log.err("==============================", .{});

    enableWFIMode();
}

/// Enable WFI("Wait For Interrupt") Mode.
/// WFI can reduce CPU power consumption.
inline fn enableWFIMode() void {
    while (true) {
        asm volatile ("wfi");
    }
}
