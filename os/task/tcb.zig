const std = @import("std");

pub const TaskControlBlock = struct {
    pid: usize,
    status: TaskStatus,
    context: TaskContext,
};

pub const TaskStatus = enum {
    Idle,
    Ready,
    Work,
    Exit,
};

pub const TaskContext = extern struct {
    ra: usize,
    sp: usize,
    s_regs: [12]usize,

    pub fn init() @This() {
        return std.mem.zeroes(TaskContext);
    }
};
