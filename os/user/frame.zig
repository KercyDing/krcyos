pub const TrapFrame = extern struct {
    zero: usize, // x0,  offset 0
    ra: usize, // x1,  offset 8
    sp: usize, // x2,  offset 16
    gp: usize, // x3,  offset 24
    tp: usize, // x4,  offset 32

    t0: usize, // x5, offset 40
    t1: usize, // x6, offset 48
    t2: usize, // x7, offset 56

    s0: usize, // x8, offset 64
    s1: usize, // x9, offset 72

    a0: usize, // x10, offset 80
    a1: usize, // x11, offset 88
    a2: usize, // x12, offset 96
    a3: usize, // x13, offset 104
    a4: usize, // x14, offset 112
    a5: usize, // x15, offset 120
    a6: usize, // x16, offset 128
    a7: usize, // x17, offset 136

    s2: usize, // x18, offset 144
    s3: usize, // x19, offset 152
    s4: usize, // x20, offset 160
    s5: usize, // x21, offset 168
    s6: usize, // x22, offset 176
    s7: usize, // x23, offset 184
    s8: usize, // x24, offset 192
    s9: usize, // x25, offset 200
    s10: usize, // x26, offset 208
    s11: usize, // x27, offset 216

    t3: usize, // x28, offset 224
    t4: usize, // x29, offset 232
    t5: usize, // x30, offset 240
    t6: usize, // x31, offset 248

    sepc: usize, // offset 256
    sstatus: usize, // offset 264
};

comptime {
    if (@offsetOf(TrapFrame, "a0") != 80) @compileError("Bad TrapFrame.a0 offset");
    if (@offsetOf(TrapFrame, "a7") != 136) @compileError("Bad TrapFrame.a7 offset");
    if (@offsetOf(TrapFrame, "sepc") != 256) @compileError("Bad TrapFrame.sepc offset");
    if (@offsetOf(TrapFrame, "sstatus") != 264) @compileError("Bad TrapFrame.sstatus offset");
    if (@sizeOf(TrapFrame) != 272) @compileError("Bad TrapFrame size");
}
