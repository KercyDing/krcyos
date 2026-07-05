const constants = @import("constants");

comptime {
    if (constants.SYS_EXIT != 0) {
        @compileError("Assuming SYS_EXIT equals 0!");
    }
    if (constants.SYS_READ != 1) {
        @compileError("Assuming SYS_READ equals 1!");
    }
    if (constants.SYS_WRITE != 2) {
        @compileError("Assuming SYS_WRITE equals 2!");
    }
}

pub export fn userEntry() linksection(".user") callconv(.naked) noreturn {
    asm volatile (
        \\
        // SYS_READ
        \\ li a7, 1
        \\ ecall
        \\
        // SYS_WRITE
        \\ li a7, 2
        \\ ecall
        \\
        // SYS_EXIT
        \\ li a7, 0
        \\ ecall
        \\
        \\ 1:
        \\ j 1b
    );
}
