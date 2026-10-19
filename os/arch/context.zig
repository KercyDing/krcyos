pub const TaskContext = extern struct {
    ra: usize,
    sp: usize,
    s_regs: [12]usize,

    pub fn init(entry_point: usize, stack_top: usize) @This() {
        return .{
            .ra = entry_point,
            .sp = stack_top,
            .s_regs = @splat(0),
        };
    }
};

comptime {
    if (@offsetOf(TaskContext, "ra") != 0) @compileError("Bad TaskContext.ra offset");
    if (@offsetOf(TaskContext, "sp") != 8) @compileError("Bad TaskContext.sp offset");
    if (@offsetOf(TaskContext, "s_regs") != 16) @compileError("Bad TaskContext.s_regs offset");
    if (@sizeOf(TaskContext) != 112) @compileError("Bad TaskContext size");
}
