const std = @import("std");

pub const TaskControlBlock = struct {
    pid: usize,
    status: TaskStatus,
    context: TaskContext,
    wakeup_tick: usize = 0,

    prev: ?*TaskControlBlock = null,
    next: ?*TaskControlBlock = null,

    pub fn init(self: *TaskControlBlock, pid: usize, entry_point: usize, stack_top: usize) void {
        self.pid = pid;
        self.status = .Ready;
        self.context = TaskContext.init(entry_point, stack_top);

        self.wakeup_tick = 0;
        self.prev = null;
        self.next = null;
    }
};

pub const TaskStatus = enum {
    Idle,
    Ready,
    Work,
    Rest,
    Exit,
};

pub const TaskContext = extern struct {
    ra: usize,
    sp: usize,
    s_regs: [12]usize,

    pub fn init(entry_point: usize, stack_pop: usize) @This() {
        return .{
            .ra = entry_point,
            .sp = stack_pop,
            .s_regs = @splat(0),
        };
    }
};
