const std = @import("std");
const console = @import("console.zig");
const sbi = @import("sbi.zig");

extern var sbss: u8;
extern var ebss: u8;
extern var boot_stack_top: u8;
export var boot_stack: [4096 * 4]u8 align(16) linksection(".bss.stack") = undefined;

export fn _start() linksection(".text.entry") callconv(.naked) noreturn {
    asm volatile (
        \\la sp, boot_stack_top
        \\call kmain
    );
    while (true) {}
}

/// Kernel main function
export fn kmain() noreturn {
    clearBss();

    const message = "KrcyOS from Zig!";
    console.println("\nHello!");
    console.println(message[0..]);

    console.print("[-] Shutdown.\n");
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
