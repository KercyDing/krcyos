const std = @import("std");
const config = @import("config");
const console = @import("console.zig");
const log = @import("logging.zig");
const banner = @import("banner.zig");

// Core
const trap = @import("trap.zig");
const pmm = @import("pmm.zig");
const tests = @import("tests.zig");

// Bare metal environment and stack
extern var sbss: u8;
extern var ebss: u8;
extern var boot_stack_top: u8;
export var boot_stack: [4096 * 4]u8 align(16) linksection(".bss.stack") = undefined;

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
    pmm.init();
    banner.show();

    tests.testAll();  // test some functions here.
    unreachable;  // due to "noreturn".
}

fn clearBss() void {
    const start_addr = @intFromPtr(&sbss);
    const end_addr = @intFromPtr(&ebss);
    const length = end_addr - start_addr;

    const start: [*]u8 = @ptrCast(&sbss);
    @memset(start[0..length], 0);
}

/// Panic handler
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = error_return_trace;
    _ = ret_addr;

    log.err("=== SHIT KERNEL PANIC ===", .{});
    log.err("{s}", .{msg});
    if (config.board == .qemu_virt) {
        log.err("Press Ctrl+A and X to exit.", .{});
    }
    log.err("=========================", .{});

    while (true) {
        asm volatile ("wfi");  // "Wait For Interrupt" can reduce CPU power consumption
    }
}
