pub const TrapFrame = extern struct {
    user_sp: usize, // offset 0
    sepc: usize, // offset 8
    sstatus: usize, // offset 16

    a0: usize, // offset 24
    a1: usize, // offset 32
    a2: usize, // offset 40
    a7: usize, // offset 48

    // make frame size 64.
    _padding: usize, // offset 56
};

comptime {
    if (@offsetOf(TrapFrame, "a7") != 48) @compileError("Bad TrapFrame layout");
    if (@sizeOf(TrapFrame) != 64) @compileError("Bad TrapFrame size");
}
