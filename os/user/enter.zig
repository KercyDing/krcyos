const constants = @import("constants");
const code = @import("code.zig");

var user_stack: [constants.PAGE_SIZE]u8 align(constants.PAGE_SIZE) linksection(".user_stack") = undefined;
var kernel_stack: [constants.PAGE_SIZE]u8 align(constants.PAGE_SIZE) = undefined;

pub fn enterUser() noreturn {
    const user_entry = @intFromPtr(&code.userEntry);
    const user_sp = @intFromPtr(&user_stack) + user_stack.len;
    const kernel_sp = @intFromPtr(&kernel_stack) + kernel_stack.len;

    asm volatile (
        \\ csrw sepc, %[entry]
        \\
        \\ csrw sscratch, %[ksp]
        \\
        \\ li t0, 0x100
        \\ csrc sstatus, t0
        \\
        \\ mv sp, %[usp]
        \\ sret
        :
        : [entry] "r" (user_entry),
          [usp] "r" (user_sp),
          [ksp] "r" (kernel_sp),
    );

    unreachable;
}
