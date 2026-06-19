pub const TrapFrame = extern struct {
    user_sp: usize,
    sepc: usize,
    sstatus: usize,

    a0: usize,
    a1: usize,
    a2: usize,
    a7: usize,

    _padding: usize, // make frame size 64
};

comptime {
    if (@offsetOf(TrapFrame, "a7") != 48) @compileError("Bad TrapFrame layout");
    if (@sizeOf(TrapFrame) != 64) @compileError("Bad TrapFrame size");
}
