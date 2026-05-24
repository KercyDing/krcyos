const std = @import("std");
const constants = @import("constants");
const csr = @import("csr.zig");
const timer = @import("timer.zig");
const task = @import("task");
const log = @import("lib").log;

const save_regs = blk: {
    var res: []const u8 = "";
    for (1..32) |i| {
        res = res ++ std.fmt.comptimePrint("sd x{d}, {d}*8(sp)\n", .{ i, i });
    }
    res = res ++
        "csrr t0, sepc\n" ++
        "sd t0, 0(sp)\n";
    break :blk res;
};

const restore_regs = blk: {
    var res: []const u8 = undefined;
    res = "ld t0, 0(sp)\n" ++
        "csrw sepc, t0\n";
    for (1..32) |i| {
        res = res ++ std.fmt.comptimePrint("ld x{d}, {d}*8(sp)\n", .{ i, i });
    }
    break :blk res;
};

/// Initialize the trap handler by seting stvec.
pub fn init() void {
    csr.write(.stvec, @intFromPtr(&trapEntry));
}

/// Trap entry point.
/// Save context, dispatch, restore and return.
export fn trapEntry() align(4) callconv(.naked) noreturn {
    asm volatile ("addi sp, sp, -256\n" ++
            save_regs ++
            "mv a0, sp\n" ++
            "call trapHandler\n" ++
            restore_regs ++
            "addi sp, sp, 256\n" ++
            "sret\n");
}

/// Dispatch traps based on scause.
export fn trapHandler(saved_sepc: *usize) void {
    const cause = csr.read(.scause);
    const epc = csr.read(.sepc);
    const tval = csr.read(.stval);

    // Bit 63 of scause: 1 = interupt, 0 = sync exception.
    const flag: u1 = @truncate(cause >> 63);
    const exception_code = cause & ~(@as(usize, 1) << 63);

    switch (flag) {
        0 => switch (exception_code) { // sync exception
            0 => std.debug.panic("Instruction Address Misaligned at 0x{x}", .{tval}),
            1 => std.debug.panic("Instruction Access Fault at 0x{x}", .{tval}),
            2 => std.debug.panic("Illegal Instruction at 0x{x}", .{epc}),
            3 => {
                log.info("Breakpoint Exception at 0x{x}", .{epc});
                saved_sepc.* = epc + getInstructionStep(epc);
            },
            4 => std.debug.panic("Load Address Misaligned at 0x{x}", .{tval}),
            5 => std.debug.panic("Load Access Fault at 0x{x}", .{tval}),
            6 => std.debug.panic("Store/AMO Address Misaligned at 0x{x}", .{tval}),
            7 => std.debug.panic("Store/AMO Access Fault at 0x{x}", .{tval}),
            8 => {
                log.info("Environment Call from U-Mode", .{});
                saved_sepc.* = epc + getInstructionStep(epc);
            },
            9 => {
                log.info("Environment Call from S-Mode", .{});
                saved_sepc.* = epc + getInstructionStep(epc);
            },
            12 => std.debug.panic("Instruction Page Fault at 0x{x}", .{tval}),
            13 => std.debug.panic("Load Page Fault at 0x{x}", .{tval}),
            15 => std.debug.panic("Store/AMO Page Fault at 0x{x}", .{tval}),
            else => std.debug.panic("Unhandled Exception: {} at 0x{x}, tval: 0x{x}", .{ exception_code, epc, tval }),
        },
        1 => switch (exception_code) { // asynchronous interruption
            1 => log.info("Supervisor Software Interrupt", .{}),
            5 => {
                timer.tick(constants.TICK_1MS * 50); // 50 ms
                task.scheduler.schedule();
            },
            9 => log.info("Supervisor External Interrupt", .{}),
            else => log.warn("Unknown Interrupt: {}", .{exception_code}),
        },
    }
}

inline fn getInstructionStep(epc: usize) usize {
    // Decode instruction length: compressed (16-bit) or standard (32-bit).
    const instruction = @as(*volatile u16, @ptrFromInt(epc)).*;
    return if ((instruction & 0b11) == 0b11) 4 else 2;
}
