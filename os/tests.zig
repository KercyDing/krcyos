const console = @import("console.zig");
const log = @import("logging.zig");
const trap = @import("trap.zig");
const pmm = @import("pmm.zig");
const vmm = @import("vmm.zig");

/// Unified test function entry.
pub fn testAll() void {
    testConsoleAndLog();
    testPmm();
    testVmm();
    testTrap();
    testPanic();
}

fn testConsoleAndLog() void {
    const message = "KrcyOS from Zig!";
    console.print("\n", .{});
    log.info("{s}", .{"Hey guys,"});
    log.info("{s}", .{message[0..]});
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
