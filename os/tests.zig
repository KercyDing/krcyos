const std = @import("std");
const constants = @import("constants");
const lib = @import("lib");
const log = lib.log;
const pmm = @import("mm").pmm;
const vmm = @import("mm").vmm;
const HeapAllocator = @import("mm").heap;

var heap_memory: [constants.HEAP_SIZE]u8 align(constants.PAGE_SIZE) = undefined;

/// Unified test function entry.
pub fn testAll() void {
    testConsole();
    testLog();
    testPmm();
    testVmm();
    testHeap();
    testTrap();
    testPanic();
}

fn testConsole() void {
    lib.console.print("\n", .{});
}

fn testLog() void {
    const message = "KrcyOS from Zig!";
    log.info("{s}", .{"Hey guys,"});
    log.info("{s}", .{message});
}

fn testPmm() void {
    log.info("", .{});
    log.info("Testing pmm...", .{});
    const p1 = pmm.alloc() orelse return;
    defer pmm.free(p1);
    const p2 = pmm.alloc() orelse return;
    const p3 = pmm.alloc() orelse return;
    defer pmm.free(p3);

    log.info("p1 @ 0x{x}", .{p1});
    log.info("p2 @ 0x{x} (Attention!)", .{p2});
    log.info("p3 @ 0x{x}", .{p3});

    pmm.free(p2);
    log.info("p2 back to pool.", .{});

    const p4 = pmm.alloc() orelse return;
    defer pmm.free(p4);
    log.info("p4 @ 0x{x} (Recycled!)", .{p4});
}

fn testVmm() void {
    log.info("", .{});
    log.info("Testing vmm...", .{});

    // Check Activation
    var satp: usize = undefined;
    asm volatile ("csrr %[ret], satp"
        : [ret] "=r" (satp),
    );

    const mode = satp >> 60;
    if (mode != 8) @panic("VMM: Sv39 not found. I'm blind!");

    log.info("SATP @ 0x{x} (Well done.)", .{satp});

    // Check Mapping
    const test_va: usize = 0x9000_0000;
    const test_pa = pmm.alloc() orelse @panic("VMM: PMM is dry.");
    defer pmm.free(test_pa);

    vmm.mapPage(vmm.root_table, test_va, test_pa, true, true, false, false);

    asm volatile ("sfence.vma");

    const ptr: *usize = @ptrFromInt(test_va);
    ptr.* = 0xdeadbeef;

    if (ptr.* != 0xdeadbeef) @panic("VMM: Teleportation failed.");
    log.info("VA 0x{x} <=> PA 0x{x} (Linked!)", .{ test_va, test_pa });
}

fn testHeap() void {
    log.info("", .{});
    log.info("Testing heap...", .{});

    const heap_start = @intFromPtr(&heap_memory);

    var heap = HeapAllocator.init(heap_start);
    log.info("Heap initialized @ 0x{x}", .{heap_start});

    // Allocate 4 for testing.
    const ptr1 = heap.alloc(30) orelse @panic("Allocate ptr1 failed!");
    log.info("Alloc(30) -> 0x{x} (Order 1, 32B)", .{ptr1});

    const ptr2 = heap.alloc(60) orelse @panic("Allocate ptr2 failed!");
    log.info("Alloc(60) -> 0x{x} (Order 2, 64B)", .{ptr2});

    const ptr3 = heap.alloc(4000) orelse @panic("Allocate ptr3 failed!");
    log.info("Alloc(4000) -> 0x{x} (Order 8, 4096B)", .{ptr3});

    if (heap.alloc(8000) != null) {
        @panic("Heap: Should reject size > 4096!");
    }
    log.info("Alloc(8000) -> null", .{});

    // Free the all of we allocated.
    heap.free(ptr1);
    heap.free(ptr2);
    heap.free(ptr3);
    log.info("Freed all ptrs!", .{});

    // Check if we could reallocate 4 complete 4096-page blocks.
    const page1 = heap.alloc(4096) orelse @panic("Heap: Allocate Page1 failed!");
    const page2 = heap.alloc(4096) orelse @panic("Heap: Allocate Page2 failed!");
    const page3 = heap.alloc(4096) orelse @panic("Heap: Allocate Page3 failed!");
    const page4 = heap.alloc(4096) orelse @panic("Heap: Allocate Page4 failed!");

    heap.free(page1);
    heap.free(page2);
    heap.free(page3);
    heap.free(page4);
    log.info("Freed all pages!", .{});

    testSTL(&heap);
}

inline fn testSTL(heap: *HeapAllocator) void {
    log.info("", .{});
    log.info("Testing vtable...", .{});
    const std_allocator = heap.allocator();

    var list: std.ArrayList(u32) = .empty;
    defer list.deinit(std_allocator);

    list.append(std_allocator, 408) catch @panic("Heap: ArrayList append 408 failed!");
    list.append(std_allocator, 2026) catch @panic("Heap: ArrayList append 2026 failed!");

    if (list.items[0] != 408 or list.items[1] != 2026) {
        @panic("Heap: ArrayList data corruption!");
    }

    log.info("ArrayList works! [{}, {}]", .{ list.items[0], list.items[1] });
}

fn testTrap() void {
    log.info("", .{});
    log.info("Testing trap...", .{});
    asm volatile ("ebreak");
}

fn testPanic() void {
    log.info("", .{});
    log.info("Testing panic...", .{});

    log.info("There's nothing fun here,", .{});
    log.info("about to fall asleep.", .{});
    log.info("", .{});

    @panic("DO NOT DISTURB ME :)");
}
