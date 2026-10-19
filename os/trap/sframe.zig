const std = @import("std");

/// S-mode trap stack frame saved by trapEntry.
pub const SFrame = extern struct {
    sepc: usize,
    ra: usize,
    sp: usize,
    gp: usize,
    tp: usize,
    t0: usize,
    t1: usize,
    t2: usize,
    s0: usize,
    s1: usize,
    a0: usize,
    a1: usize,
    a2: usize,
    a3: usize,
    a4: usize,
    a5: usize,
    a6: usize,
    a7: usize,
    s2: usize,
    s3: usize,
    s4: usize,
    s5: usize,
    s6: usize,
    s7: usize,
    s8: usize,
    s9: usize,
    s10: usize,
    s11: usize,
    t3: usize,
    t4: usize,
    t5: usize,
    t6: usize,

    /// SFrame fields in layout order.
    pub const Field = std.meta.FieldEnum(SFrame);

    /// Size of SFrame in bytes.
    pub const SIZE = @sizeOf(SFrame);

    /// Get the byte offset of an SFrame field.
    pub inline fn offsetOf(comptime field: Field) usize {
        return @offsetOf(SFrame, @tagName(field));
    }
};

comptime {
    const info = @typeInfo(SFrame.Field).@"enum";
    for (info.field_names, info.field_values) |name, value| {
        if (@offsetOf(SFrame, name) != value * @sizeOf(usize)) {
            @compileError("Bad SFrame field offset");
        }
    }

    if (SFrame.SIZE != info.field_names.len * @sizeOf(usize)) @compileError("Bad SFrame size");
}
