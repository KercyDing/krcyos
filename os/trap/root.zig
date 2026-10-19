//! os/trap/root.zig

const std = @import("std");

const constants = @import("constants");
const abi = @import("abi");
const lib = @import("lib");
const arch = @import("arch");
const task = @import("task");
const syscall = @import("syscall");

const csr = arch.csr;
const timer = arch.timer;

const TrapFrame = abi.TrapFrame;
const SFrame = @import("sframe.zig").SFrame;

// zig fmt: off
const saved_regs = [_]SFrame.Field{
    .ra, .sp, .gp, .tp,
    .t0, .t1, .t2,
    .s0, .s1,
    .a0, .a1, .a2, .a3, .a4, .a5, .a6, .a7,
    .s2, .s3, .s4, .s5, .s6, .s7, .s8, .s9, .s10, .s11,
    .t3, .t4, .t5, .t6,
};
// zig fmt: on

const u_save_regs = blk: {
    var res: []const u8 = "\n";

    // t0 = kernel_sp
    // sp = user_sp
    // sscratch = user_t0
    res = res ++ std.fmt.comptimePrint("addi t0, t0, -{d}\n", .{TrapFrame.SIZE});

    // Save x0-x4.
    for (0..5) |i| {
        const field: TrapFrame.Field = @fromBackingInt(@intCast(i));
        res = res ++ std.fmt.comptimePrint("sd x{d}, {d}(t0)\n", .{ i, TrapFrame.offsetOf(field) });
    }

    // Save original user t0 from sscratch.
    // user_sp is already saved, so sp can be used as a temp now.
    res = res ++
        "csrr sp, sscratch\n" ++
        std.fmt.comptimePrint("sd sp, {d}(t0)\n", .{TrapFrame.offsetOf(.t0)});

    // Save x6-x31.
    // Skip x5/t0 because it was saved from sscratch.
    for (6..32) |i| {
        const field: TrapFrame.Field = @fromBackingInt(@intCast(i));
        res = res ++ std.fmt.comptimePrint("sd x{d}, {d}(t0)\n", .{ i, TrapFrame.offsetOf(field) });
    }

    // Save sepc and sstatus.
    // sp is just a temporary now.
    res = res ++ "csrr sp, sepc\n" ++
        std.fmt.comptimePrint("sd sp, {d}(t0)\n", .{TrapFrame.offsetOf(.sepc)}) ++ "csrr sp, sstatus\n" ++
        std.fmt.comptimePrint("sd sp, {d}(t0)\n", .{TrapFrame.offsetOf(.sstatus)});

    // Mark current execution as kernel mode.
    res = res ++
        "csrw sscratch, zero\n";

    break :blk res;
};

const u_restore_regs = blk: {
    var res: []const u8 = "\n";

    // sp = TrapFrame*

    // Restore sepc and sstatus.
    res = res ++
        std.fmt.comptimePrint("ld t0, {d}(sp)\n", .{TrapFrame.offsetOf(.sepc)}) ++
        "csrw sepc, t0\n" ++
        std.fmt.comptimePrint("ld t0, {d}(sp)\n", .{TrapFrame.offsetOf(.sstatus)}) ++
        "csrw sstatus, t0\n";

    // Prepare sscratch for the next U-mode trap.
    // sp + TrapFrame.SIZE = kernel_sp
    res = res ++ std.fmt.comptimePrint(
        "addi t0, sp, {d}\n" ++
            "csrw sscratch, t0\n",
        .{TrapFrame.SIZE},
    );

    // Restore all user registers except sp/x2 and t0/x5.
    // sp must stay as TrapFrame* until the end.
    // t0 was used above, so restore it near the end.
    for (1..32) |i| {
        if (i == 2) continue; // sp
        if (i == 5) continue; // t0
        const field: TrapFrame.Field = @fromBackingInt(@intCast(i));
        res = res ++ std.fmt.comptimePrint("ld x{d}, {d}(sp)\n", .{ i, TrapFrame.offsetOf(field) });
    }

    // Restore t0 and user sp last.
    res = res ++
        std.fmt.comptimePrint("ld t0, {d}(sp)\n", .{TrapFrame.offsetOf(.t0)}) ++
        std.fmt.comptimePrint("ld sp, {d}(sp)\n", .{TrapFrame.offsetOf(.sp)}) ++
        "sret\n";

    break :blk res;
};

const s_save_regs = blk: {
    var res: []const u8 = "\n";

    // Save x1-x31.
    for (saved_regs) |reg| {
        res = res ++ std.fmt.comptimePrint("sd x{d}, {d}(sp)\n", .{ @backingInt(reg), SFrame.offsetOf(reg) });
    }
    res = res ++
        "csrr t0, sepc\n" ++
        std.fmt.comptimePrint("sd t0, {d}(sp)\n", .{SFrame.offsetOf(.sepc)});

    break :blk res;
};

const s_restore_regs = blk: {
    var res: []const u8 = "\n";

    // Restore sepc first.
    // t0 will be restored later from the saved frame.
    res = res ++
        std.fmt.comptimePrint("ld t0, {d}(sp)\n", .{SFrame.offsetOf(.sepc)}) ++
        "csrw sepc, t0\n";

    // x2 is sp. It is restored by "addi sp, sp, SFrame.SIZE" later.
    for (saved_regs) |reg| {
        if (reg == .sp) continue;
        res = res ++ std.fmt.comptimePrint("ld x{d}, {d}(sp)\n", .{ @backingInt(reg), SFrame.offsetOf(reg) });
    }

    break :blk res;
};

/// Initialize the trap handler by setting stvec.
pub fn init() void {
    csr.write(.stvec, @intFromPtr(&trapEntry));

    // Clear sscratch.
    asm volatile ("csrw sscratch, zero");
}

/// Trap entry point.
/// Save context, dispatch, restore and return.
export fn trapEntry() align(4) callconv(.naked) noreturn {
    // zig fmt: off
    asm volatile (
        // Common entry.
        \\ csrrw t0, sscratch, t0
        \\ beqz t0, 1f
        \\
        // U-mode trap path.
        ++ u_save_regs ++
        \\ mv sp, t0
        \\ mv a0, sp
        \\ call userTrapHandler
        ++ u_restore_regs ++
        \\
        // S-mode trap path.
        \\ 1:
        \\ csrrw t0, sscratch, t0
        ++ std.fmt.comptimePrint("\naddi sp, sp, -{d}\n", .{SFrame.SIZE}) ++
        s_save_regs ++
        \\ mv a0, sp
        \\ call trapHandler
        ++ s_restore_regs ++
        std.fmt.comptimePrint("addi sp, sp, {d}\n", .{SFrame.SIZE}) ++
        \\ sret
    );
    // zig fmt: on
}

/// Dispatch traps based on scause.
export fn trapHandler(frame: *SFrame) void {
    const cause = csr.read(.scause);
    const epc = csr.read(.sepc);
    const tval = csr.read(.stval);

    // MSB of scause: 1 = interrupt, 0 = sync exception.
    const is_interrupt = (cause & csr.SCAUSE_INTERRUPT_BIT) != 0;
    const exception_code = cause & ~csr.SCAUSE_INTERRUPT_BIT;

    if (!is_interrupt) {
        switch (exception_code) {
            0 => std.debug.panic("Instruction Address Misaligned at 0x{x}", .{tval}),
            1 => std.debug.panic("Instruction Access Fault at 0x{x}", .{tval}),
            2 => std.debug.panic("Illegal Instruction at 0x{x}", .{epc}),
            3 => {
                lib.info("Breakpoint Exception at 0x{x}", .{epc});
                frame.sepc = epc + getInstructionStep(epc);
            },
            4 => std.debug.panic("Load Address Misaligned at 0x{x}", .{tval}),
            5 => std.debug.panic("Load Access Fault at 0x{x}", .{tval}),
            6 => std.debug.panic("Store/AMO Address Misaligned at 0x{x}", .{tval}),
            7 => std.debug.panic("Store/AMO Access Fault at 0x{x}", .{tval}),
            8 => {
                lib.info("Environment Call from U-Mode", .{});
                frame.sepc = epc + getInstructionStep(epc);
            },
            9 => {
                lib.info("Environment Call from S-Mode", .{});
                frame.sepc = epc + getInstructionStep(epc);
            },
            12 => std.debug.panic("Instruction Page Fault at 0x{x}", .{tval}),
            13 => std.debug.panic("Load Page Fault at 0x{x}", .{tval}),
            15 => std.debug.panic("Store/AMO Page Fault at 0x{x}", .{tval}),
            else => std.debug.panic("Unhandled Exception: {} at 0x{x}, tval: 0x{x}", .{
                exception_code,
                epc,
                tval,
            }),
        }

        return;
    }

    switch (exception_code) {
        1 => lib.info("Supervisor Software Interrupt", .{}),
        5 => {
            timer.tick(constants.TIMER_TICK_1MS * 50); // 50 ms
            task.scheduler.schedule();
        },
        9 => lib.info("Supervisor External Interrupt", .{}),
        else => lib.warn("Unknown Interrupt: {}", .{exception_code}),
    }
}

/// Dispatch user-mode traps.
export fn userTrapHandler(frame: *TrapFrame) void {
    const cause = csr.read(.scause);
    const is_interrupt = (cause & csr.SCAUSE_INTERRUPT_BIT) != 0;
    const exception_code = cause & ~csr.SCAUSE_INTERRUPT_BIT;

    if (is_interrupt or exception_code != 8) { // ecall from user.
        const epc = csr.read(.sepc);
        const tval = csr.read(.stval);

        lib.err("Unexpected user trap: scause=0x{x}, sepc=0x{x}, stval=0x{x}", .{
            cause,
            epc,
            tval,
        });
        lib.drainLogs();
        @panic("Unexpected user trap.");
    }

    syscall.handle(frame);
}

inline fn getInstructionStep(epc: usize) usize {
    // Decode instruction length:
    // compressed instruction: 16-bit
    // standard instruction  : 32-bit
    const instruction = @as(*volatile u16, @ptrFromInt(epc)).*;
    return if ((instruction & 0b11) == 0b11) 4 else 2;
}
