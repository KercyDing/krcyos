const constants = @import("constants");

comptime {
    if (constants.SYS_EXIT != 0) {
        @compileError("Assuming SYS_EXIT equals 0!");
    }
    if (constants.SYS_WRITE != 1) {
        @compileError("Assuming SYS_WRITE equals 1!");
    }
    if (constants.SYS_READ != 2) {
        @compileError("Assuming SYS_READ equals 2!");
    }
}

pub inline fn sysExit() noreturn {
    asm volatile (
        \\ li a7, 0
        \\ ecall
    );

    // sysExit should not return U-mode.
    unreachable;
}

pub inline fn sysWrite() void {
    asm volatile (
        \\ li a7, 1
        \\ ecall
    );
}

pub inline fn sysRead() void {
    asm volatile (
        \\ li a7, 2
        \\ ecall
    );
}

pub export fn userEntry() linksection(".user") noreturn {
    sysWrite();

    sysRead();

    sysExit();
}
