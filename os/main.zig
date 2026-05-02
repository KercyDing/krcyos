const std = @import("std");
const config = @import("config");
const sbi = @import("sbi.zig");
const console = @import("console.zig");
const log = @import("logging.zig");

extern var sbss: u8;
extern var ebss: u8;
extern var boot_stack_top: u8;
export var boot_stack: [4096 * 4]u8 align(16) linksection(".bss.stack") = undefined;

export fn _start() linksection(".text.entry") callconv(.naked) noreturn {
    asm volatile (
        \\la sp, boot_stack_top
        \\call main
    );
    while (true) {}
}

/// Kernel main function
export fn main() noreturn {
    clearBss();

    const message = "KrcyOS from Zig!";
    console.print("\n", .{});
    log.info("{s}", .{"Hey guys,"});
    log.info("{s}", .{message[0..]});

    log.info("Testing panic...", .{});

    // var zero: usize = 0;
    // const volatile_zero_ptr: *volatile usize = &zero;
    // _ = 100 / volatile_zero_ptr.*;
    // unreachable;

    console.println("There's nothing fun here...", .{});
    @panic("I'm bored, KrcyOS needs to sleep!");
}

/// Clear bss function
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
        asm volatile ("wfi");  // "Wait For Interrupt", reduce CPU power consumption
    }
}
