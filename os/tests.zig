const console = @import("console.zig");
const log = @import("logging.zig");
const trap = @import("trap.zig");
const pmm = @import("pmm.zig");

/// Unified test function entry.
pub fn testAll() void {
    testConsoleAndLog();
    testPmm();
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
    const p1 = pmm.alloc().?;
    const p2 = pmm.alloc().?;
    const p3 = pmm.alloc().?;

    log.info("Allocated p1: 0x{x}", .{p1});
    log.info("Allocated p2: 0x{x}", .{p2});
    log.info("Allocated p3: 0x{x}", .{p3});

    pmm.free(p2);
    log.info("Freed p2.", .{});

    const p4 = pmm.alloc().?;
    log.info("Allocated p4: 0x{x}", .{p4});
}

fn testTrap() void {
    log.info("", .{});
    log.info("Testing trap...", .{});
    asm volatile (
        \\ ebreak
    );
}

fn testPanic() void {
    log.info("", .{});
    log.info("Testing panic...", .{});

    // var zero: usize = 0;
    // const volatile_zero_ptr: *volatile usize = &zero;
    // _ = 100 / volatile_zero_ptr.*;
    // unreachable;

    log.info("There's nothing fun here,", .{});
    log.info("coming to sleep soon.", .{});
    @panic("I'm sleeping...");
}
