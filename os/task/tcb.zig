const arch = @import("arch");

pub const TaskControlBlock = struct {
    pid: usize,
    status: TaskStatus,
    context: arch.TaskContext,
    wakeup_tick: usize = 0,

    prev: ?*TaskControlBlock = null,
    next: ?*TaskControlBlock = null,

    pub fn init(self: *TaskControlBlock, pid: usize, entry_point: usize, stack_top: usize) void {
        self.pid = pid;
        self.status = .Ready;
        self.context = arch.TaskContext.init(entry_point, stack_top);

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
