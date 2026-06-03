const std = @import("std");
const constants = @import("constants");
const lib = @import("lib");
const pmm = @import("mm").pmm;
const vmm = @import("mm").vmm;
const HeapAllocator = @import("mm").heap;
const timer = @import("arch").timer;
const task = @import("task");

/// Unified test function entry.
pub fn testAll() void {
    testLog();
    testPmm();
    testVmm();
    testHeap();
    testTrap();
    testTask();
}

fn testLog() void {
    const message = "KrcyOS from Zig!";
    lib.info("{s}", .{"Hey guys,"});
    lib.info("{s}", .{message});
}

fn testPmm() void {
    lib.info("", .{});
    lib.info("Testing pmm...", .{});
    const p1 = pmm.alloc() catch return;
    defer pmm.free(p1);
    const p2 = pmm.alloc() catch return;
    const p3 = pmm.alloc() catch return;
    defer pmm.free(p3);

    lib.info("p1 @ 0x{x}", .{p1});
    lib.info("p2 @ 0x{x} (Attention!)", .{p2});
    lib.info("p3 @ 0x{x}", .{p3});

    pmm.free(p2);
    lib.info("p2 back to pool.", .{});

    const p4 = pmm.alloc() catch return;
    defer pmm.free(p4);
    lib.info("p4 @ 0x{x} (Recycled!)", .{p4});
}

fn testVmm() void {
    lib.info("", .{});
    lib.info("Testing vmm...", .{});

    // Check Activation
    var satp: usize = undefined;
    asm volatile ("csrr %[ret], satp"
        : [ret] "=r" (satp),
    );

    const mode = satp >> 60;
    if (mode != 8) @panic("VMM: Sv39 not found. I'm blind!");

    lib.info("SATP @ 0x{x} (Well done.)", .{satp});

    // Check Mapping
    const test_va: usize = 0x9000_0000;
    const test_pa = pmm.alloc() catch @panic("VMM: PMM is dry.");
    defer pmm.free(test_pa);

    vmm.mapPage(vmm.root_table, test_va, test_pa, true, true, false, false);

    asm volatile ("sfence.vma");

    const ptr: *usize = @ptrFromInt(test_va);
    ptr.* = 0xdeadbeef;

    if (ptr.* != 0xdeadbeef) @panic("VMM: Teleportation failed.");
    lib.info("VA 0x{x} <=> PA 0x{x} (Linked!)", .{ test_va, test_pa });
}

var heap_memory: [constants.HEAP_SIZE]u8 align(constants.PAGE_SIZE) = undefined;

fn testHeap() void {
    lib.info("", .{});
    lib.info("Testing heap...", .{});

    const heap_start = @intFromPtr(&heap_memory);

    var heap = HeapAllocator.init(heap_start);
    lib.info("Heap initialized @ 0x{x}", .{heap_start});

    // Allocate 4 for testing.
    const ptr1 = heap.alloc(30) catch @panic("Allocate ptr1 failed!");
    lib.info("Alloc(30) -> 0x{x} (Order 1, 32B)", .{ptr1});

    const ptr2 = heap.alloc(60) catch @panic("Allocate ptr2 failed!");
    lib.info("Alloc(60) -> 0x{x} (Order 2, 64B)", .{ptr2});

    const ptr3 = heap.alloc(4000) catch @panic("Allocate ptr3 failed!");
    lib.info("Alloc(4000) -> 0x{x} (Order 8, 4096B)", .{ptr3});

    if (heap.alloc(8000)) |_| {
        @panic("Heap: Should reject size > 4096!");
    } else |_| {
        lib.info("Alloc(8000) -> null", .{});
    }

    // Free the all of we allocated.
    heap.free(ptr1);
    heap.free(ptr2);
    heap.free(ptr3);
    lib.info("Freed all ptrs!", .{});

    // Check if we could reallocate 4 complete 4096-page blocks.
    const page1 = heap.alloc(4096) catch @panic("Heap: Allocate Page1 failed!");
    const page2 = heap.alloc(4096) catch @panic("Heap: Allocate Page2 failed!");
    const page3 = heap.alloc(4096) catch @panic("Heap: Allocate Page3 failed!");
    const page4 = heap.alloc(4096) catch @panic("Heap: Allocate Page4 failed!");

    heap.free(page1);
    heap.free(page2);
    heap.free(page3);
    heap.free(page4);

    testSTL(&heap);
}

inline fn testSTL(heap: *HeapAllocator) void {
    lib.info("", .{});
    lib.info("Testing vtable...", .{});
    const std_allocator = heap.allocator();

    var list: std.ArrayList(u32) = .empty;
    defer list.deinit(std_allocator);

    list.append(std_allocator, 408) catch @panic("Heap: ArrayList append 408 failed!");
    list.append(std_allocator, 2026) catch @panic("Heap: ArrayList append 2026 failed!");

    if (list.items[0] != 408 or list.items[1] != 2026) {
        @panic("Heap: ArrayList data corruption!");
    }

    lib.info("ArrayList works! [{}, {}]", .{ list.items[0], list.items[1] });
}

fn testTask() void {
    lib.info("", .{});
    lib.info("Testing scheduler...", .{});

    task.scheduler.initTask(@intFromPtr(&taskA));
    task.scheduler.initTask(@intFromPtr(&taskB));

    lib.info("Tasks initialized!", .{});
}

const task_a_max_runs: usize = 10;
const task_b_max_runs: usize = 5;
const task_a_sleep_ticks: usize = 100_000;
const task_b_sleep_ticks: usize = 200_000;

var count_a: usize = 0;
var count_b: usize = 0;

fn taskA() void {
    timer.enable();

    while (count_a < task_a_max_runs) {
        count_a += 1;
        logTaskRun("A", count_a, task_a_max_runs);
        task.scheduler.sleepTicks(task_a_sleep_ticks);
    }

    logTaskExit("A", count_a);
    if (count_b >= task_b_max_runs) testPanic();

    task.scheduler.exitTask();
}

fn taskB() void {
    timer.enable();

    while (count_b < task_b_max_runs) {
        count_b += 1;
        logTaskRun("B", count_b, task_b_max_runs);
        task.scheduler.sleepTicks(task_b_sleep_ticks);
    }

    logTaskExit("B", count_b);
    if (count_a >= task_a_max_runs) testPanic();

    task.scheduler.exitTask();
}

fn logTaskRun(comptime name: []const u8, current: usize, max: usize) void {
    lib.info("{s} -> tick={} run {}/{}", .{
        name,
        timer.getTime(),
        current,
        max,
    });
}

fn logTaskExit(comptime name: []const u8, total_runs: usize) void {
    lib.info("{s} -> tick={} exit after {} runs", .{
        name,
        timer.getTime(),
        total_runs,
    });
}

fn testPanic() void {
    lib.info("Both tasks completed.", .{});
    lib.info("", .{});
    lib.warn("Testing panic...", .{});
    @panic("Mission Accomplished!");
}

fn testTrap() void {
    lib.info("", .{});
    lib.info("Testing trap...", .{});
    asm volatile ("ebreak");
}
