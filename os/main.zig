const std = @import("std");

extern var sbss: u8;
extern var ebss: u8;
extern var boot_stack_top: u8;

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

    const hello = "Hello, KrcyOS from Zig!\n";
    for (hello) |char| {
        consolePutchar(char);
    }

    while (true) {}
}

/// Clear bss function
fn clearBss() void {
    const start_addr = @intFromPtr(&sbss);
    const end_addr = @intFromPtr(&ebss);
    const length = end_addr - start_addr;

    const start: [*]u8 = @ptrCast(&sbss);
    @memset(start[0..length], 0);
}

// Yes, if you write it in pure asm, it would be like:
//
// li a7, 1
// li a6, 0
// ecall
// ret
//
fn consolePutchar(char: u8) void {
    _ = asm volatile ("ecall"
        : [ret] "={a0}" (-> usize)
        : [eid] "{a7}" (0x01),
          [fid] "{a6}" (0),
          [arg0] "{a0}" (char)
    );
}

export var boot_stack: [4096 * 4]u8 align(16) linksection(".bss.stack") = undefined;
