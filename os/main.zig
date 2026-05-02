const std = @import("std");
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

    console.println("There's nothing fun here.", .{});
    log.warn("Shutdown.", .{});
    sbi.shutdown(true);
}

/// Clear bss function
fn clearBss() void {
    const start_addr = @intFromPtr(&sbss);
    const end_addr = @intFromPtr(&ebss);
    const length = end_addr - start_addr;

    const start: [*]u8 = @ptrCast(&sbss);
    @memset(start[0..length], 0);
}
