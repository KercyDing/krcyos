const constants = @import("constants");
const arch = @import("arch");

const csr = arch.csr;

const code = @import("code.zig");

var user_stack: [constants.PAGE_SIZE]u8 align(constants.PAGE_SIZE) linksection(".user_stack") = undefined;
var kernel_stack: [constants.PAGE_SIZE]u8 align(constants.PAGE_SIZE) = undefined;

pub fn enterUser() noreturn {
    const user_entry = @intFromPtr(&code.userEntry);
    const user_sp = @intFromPtr(&user_stack) + user_stack.len;
    const kernel_sp = @intFromPtr(&kernel_stack) + kernel_stack.len;

    csr.write(.sepc, user_entry);
    csr.write(.sscratch, kernel_sp);
    csr.clearBits(.sstatus, csr.SSTATUS_SPP);

    asm volatile (
        \\ mv sp, %[usp]
        \\ sret
        :
        : [usp] "r" (user_sp),
    );

    unreachable;
}
