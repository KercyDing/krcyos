const std = @import("std");
const constants = @import("constants");
const arch = @import("arch");
const lib = @import("lib");
const tcb = @import("tcb.zig");

var task_pool: [constants.TASK_MAX_COUNT]tcb.TaskControlBlock = undefined;
var task_stacks: [constants.TASK_MAX_COUNT][constants.TASK_STACK_SIZE]u8 align(16) = undefined;
var curr_task: ?*tcb.TaskControlBlock = null;
var task_active_nums: usize = 0;

var run_queue: ?*tcb.TaskControlBlock = null;
var sleep_queue: ?*tcb.TaskControlBlock = null;
var idle_tcb: tcb.TaskControlBlock = undefined;

var boot_context: tcb.TaskContext = undefined;
var is_first_run: bool = true;

extern fn switch_to(old_ctx: *tcb.TaskContext, new_ctx: *tcb.TaskContext) void;

/// Initialize the scheduler and set up the idle task.
pub fn init(stack_top: usize) void {
    idle_tcb.init(0, @intFromPtr(&idleTask), stack_top);
}

fn idleTask() void {
    while (true) {
        lib.drainLogs();
        arch.wfi();
    }
}

/// Create a new task and add it to the run queue.
pub fn initTask(entry_point: usize) void {
    lib.assertMsg(task_active_nums < constants.TASK_MAX_COUNT, "Task pool is full!", @src());

    const target_tcb_pid = task_active_nums;
    const target_tcb_ptr = &task_pool[target_tcb_pid];

    const stack_bottom_addr = @intFromPtr(&task_stacks[target_tcb_pid]);
    const stack_top_addr = stack_bottom_addr + constants.TASK_STACK_SIZE;

    target_tcb_ptr.init(target_tcb_pid, entry_point, stack_top_addr);
    pushToRunQueue(target_tcb_ptr);

    task_active_nums += 1;
}

/// Wake sleeping tasks and switch context to the next ready task.
pub fn schedule() void {
    lib.assertMsg(task_active_nums > 0, "No tasks to schedule!", @src());

    var curr_opt = sleep_queue;
    while (curr_opt) |curr_node| {
        const next_node = curr_node.next;

        if (curr_node.wakeup_tick <= arch.timer.getTime()) {
            curr_node.status = .Ready;
            removeNode(curr_node);
            pushToRunQueue(curr_node);
        }
        curr_opt = next_node;
    }

    var next_task: *tcb.TaskControlBlock = undefined;

    if (run_queue == null) {
        next_task = &idle_tcb;
    } else {
        if (curr_task != null and curr_task.?.status == .Work) {
            next_task = curr_task.?.next.?;
        } else {
            next_task = run_queue.?;
        }

        if (curr_task != null and curr_task.? == next_task and !is_first_run) return;

        if (curr_task != null and curr_task.?.status == .Work) {
            curr_task.?.status = .Ready;
        }

        next_task.status = .Work;
        run_queue = next_task;
    }

    const prev_task = curr_task;
    curr_task = next_task;

    if (is_first_run) {
        is_first_run = false;
        switch_to(&boot_context, &next_task.context);
    } else {
        switch_to(&prev_task.?.context, &next_task.context);
    }
}

/// Exit the current task and remove it from the queue.
pub fn exitTask() noreturn {
    const target_tcb = curr_task.?;

    target_tcb.status = .Exit;

    removeNode(target_tcb);

    schedule();

    @panic("The exited task resurrected!");
}

/// Put the current task to sleep for the given number of ticks.
pub fn sleepTicks(wait_ticks: usize) void {
    const target_tcb = curr_task.?;

    target_tcb.wakeup_tick = arch.timer.getTime() + wait_ticks;
    target_tcb.status = .Rest;

    removeNode(target_tcb);
    pushToSleepQueue(target_tcb);

    schedule();
}

/// Insert a task node at the tail of the run queue.
fn pushToRunQueue(node: *tcb.TaskControlBlock) void {
    if (run_queue == null) {
        @branchHint(.cold);
        run_queue = node;
        node.prev = node;
        node.next = node;
        return;
    }

    const head = run_queue.?;
    const tail = head.prev.?;

    tail.next = node;
    node.prev = tail;
    node.next = head;
    head.prev = node;
}

/// Pushe a task node to the head of the sleep queue.
fn pushToSleepQueue(node: *tcb.TaskControlBlock) void {
    node.next = sleep_queue;
    node.prev = null;

    if (sleep_queue != null) sleep_queue.?.prev = node;

    sleep_queue = node;
}

/// Remove a task node from its current queue.
fn removeNode(node: *tcb.TaskControlBlock) void {
    if (node == run_queue) {
        if (node.next == node) {
            @branchHint(.cold);
            run_queue = null;
        } else {
            run_queue = node.next;
        }
    } else if (node == sleep_queue) {
        sleep_queue = node.next;
    }

    if (node.prev != null) node.prev.?.next = node.next;
    if (node.next != null) node.next.?.prev = node.prev;

    node.prev = null;
    node.next = null;
}
