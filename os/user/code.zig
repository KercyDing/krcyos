//! Monolithic user smoke test for temporary.

const constants = @import("constants");

comptime {
    if (constants.SYS_EXIT != 0) {
        @compileError("Assuming SYS_EXIT equals 0!");
    }
    if (constants.SYS_WRITE != 1) {
        @compileError("Assuming SYS_WRITE equals 1!");
    }
}

export const user_msg: [17]u8 linksection(".user") = "Hello from user!\n".*;

pub export fn userEntry() linksection(".user") callconv(.naked) noreturn {
    asm volatile (
        \\ li a0, 1
        \\ la a1, user_msg
        \\ li a2, 17
        \\ li a7, 1
        \\ ecall
        \\
        \\ li a7, 0
        \\ ecall
        \\
        \\ 1:
        \\ j 1b
    );
}
