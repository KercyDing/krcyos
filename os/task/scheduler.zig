const std = @import("std");
const constants = @import("constants");
const lib = @import("lib");
const tcb = @import("tcb.zig");

var task_pool: [constants.TASK_MAX_COUNT]tcb.TaskControlBlock = undefined;
var task_stacks: [constants.TASK_MAX_COUNT][constants.TASK_STACK_SIZE]u8 align(16) = undefined;
var task_active_nums: usize = 0;
var task_curr_idx: usize = 0;

var boot_context: tcb.TaskContext = undefined;
var is_first_run: bool = true;

extern fn switch_to(old_ctx: *tcb.TaskContext, new_ctx: *tcb.TaskContext) void;

pub fn initTask(entry_point: usize) void {
    lib.assertMsg(task_active_nums < constants.TASK_MAX_COUNT, "Task pool is full!", @src());

    const target_tcb_pid = task_active_nums;
    const target_tcb_ptr = &task_pool[target_tcb_pid];

    // Init the target tcb.
    target_tcb_ptr.pid = target_tcb_pid;
    target_tcb_ptr.status = .Ready;
    target_tcb_ptr.context = tcb.TaskContext.init();

    target_tcb_ptr.context.ra = entry_point;

    const stack_bottom_addr = @intFromPtr(&task_stacks[target_tcb_pid]);
    target_tcb_ptr.context.sp = stack_bottom_addr + constants.TASK_STACK_SIZE;

    task_active_nums += 1;
}

pub fn schedule() void {
    lib.assertMsg(task_active_nums > 0, "No tasks to schedule!", @src());

    // Rotational scheduling.
    const task_next_idx = (task_curr_idx + 1) % task_active_nums;
    if (task_next_idx == task_curr_idx and !is_first_run) return;

    const task_curr_ptr = &task_pool[task_curr_idx];
    const task_next_ptr = &task_pool[task_next_idx];

    task_curr_ptr.status = .Ready;
    task_next_ptr.status = .Work;
    task_curr_idx = task_next_idx;

    if (is_first_run) {
        is_first_run = false;
        switch_to(&boot_context, &task_next_ptr.context);
    } else {
        switch_to(&task_curr_ptr.context, &task_next_ptr.context);
    }
}

pub fn yield() void {
    schedule();
}
