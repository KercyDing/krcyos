const std = @import("std");
const constants = @import("constants");
const csr = @import("csr.zig");
const lib = @import("lib");
const timer = @import("timer.zig");
const task = @import("task");
const user = @import("user");

const SSTATUS_INTERRUPT_BIT: usize = @as(usize, 1) << 63;

const U_TRAP_FRAME_SIZE: usize = @sizeOf(user.TrapFrame);

const u_save_regs = blk: {
    var res: []const u8 = "\n";

    // t0 = kernel_sp
    // sp = user_sp
    // sscratch = user_t0
    res = res ++ std.fmt.comptimePrint("addi t0, t0, -{d}\n", .{U_TRAP_FRAME_SIZE});

    // Save x0-x4.
    res = res ++
        "sd zero, 0(t0)\n" ++
        "sd x1, 8(t0)\n" ++ // ra
        "sd x2, 16(t0)\n" ++ // user sp
        "sd x3, 24(t0)\n" ++ // gp
        "sd x4, 32(t0)\n"; // tp

    // Save original user t0 from sscratch.
    // user_sp is already saved, so sp can be used as a temp now.
    res = res ++
        "csrr sp, sscratch\n" ++
        "sd sp, 40(t0)\n";

    // Save x6-x31.
    // Skip x5/t0 because it was saved from sscratch.
    for (6..32) |i| {
        res = res ++ std.fmt.comptimePrint("sd x{d}, {d}(t0)\n", .{ i, i * 8 });
    }

    // Save sepc and sstatus.
    // sp is just a temporary now.
    res = res ++
        "csrr sp, sepc\n" ++
        "sd sp, 256(t0)\n" ++
        "csrr sp, sstatus\n" ++
        "sd sp, 264(t0)\n";

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
        "ld t0, 256(sp)\n" ++
        "csrw sepc, t0\n" ++
        "ld t0, 264(sp)\n" ++
        "csrw sstatus, t0\n";

    // Prepare sscratch for the next U-mode trap.
    // sp + 272 = kernel_sp
    res = res ++ std.fmt.comptimePrint(
        "addi t0, sp, {d}\n" ++
            "csrw sscratch, t0\n",
        .{U_TRAP_FRAME_SIZE},
    );

    // Restore all user registers except sp/x2 and t0/x5.
    // sp must stay as TrapFrame* until the end.
    // t0 was used above, so restore it near the end.
    for (1..32) |i| {
        if (i == 2) continue; // sp
        if (i == 5) continue; // t0
        res = res ++ std.fmt.comptimePrint("ld x{d}, {d}(sp)\n", .{ i, i * 8 });
    }

    // Restore t0 and user sp last.
    res = res ++
        "ld t0, 40(sp)\n" ++
        "ld sp, 16(sp)\n" ++
        "sret\n";

    break :blk res;
};

const s_save_regs = blk: {
    var res: []const u8 = "\n";

    // Save x1-x31.
    for (1..32) |i| {
        res = res ++ std.fmt.comptimePrint("sd x{d}, {d}(sp)\n", .{ i, i * 8 });
    }
    res = res ++
        "csrr t0, sepc\n" ++
        "sd t0, 0(sp)\n";

    break :blk res;
};

const s_restore_regs = blk: {
    var res: []const u8 = "\n";

    // Restore sepc first.
    // t0 will be restored later from the saved frame.
    res = res ++
        "ld t0, 0(sp)\n" ++
        "csrw sepc, t0\n";

    for (1..32) |i| {
        if (i == 2) continue; // x2 is sp. Restore it by "addi sp, sp, 256" later.
        res = res ++ std.fmt.comptimePrint("ld x{d}, {d}(sp)\n", .{ i, i * 8 });
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
    asm volatile (
        \\
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
        \\ addi sp, sp, -256
    ++ s_save_regs ++
        \\ mv a0, sp
        \\ call trapHandler
    ++ s_restore_regs ++
        \\ addi sp, sp, 256
        \\ sret
    );
}

/// Dispatch traps based on scause.
export fn trapHandler(saved_sepc: *usize) void {
    const cause = csr.read(.scause);
    const epc = csr.read(.sepc);
    const tval = csr.read(.stval);

    // Bit 63 of scause: 1 = interrupt, 0 = sync exception.
    const is_interrupt = (cause & SSTATUS_INTERRUPT_BIT) != 0;
    const exception_code = cause & ~SSTATUS_INTERRUPT_BIT;

    if (!is_interrupt) {
        switch (exception_code) {
            0 => std.debug.panic("Instruction Address Misaligned at 0x{x}", .{tval}),
            1 => std.debug.panic("Instruction Access Fault at 0x{x}", .{tval}),
            2 => std.debug.panic("Illegal Instruction at 0x{x}", .{epc}),
            3 => {
                lib.info("Breakpoint Exception at 0x{x}", .{epc});
                saved_sepc.* = epc + getInstructionStep(epc);
            },
            4 => std.debug.panic("Load Address Misaligned at 0x{x}", .{tval}),
            5 => std.debug.panic("Load Access Fault at 0x{x}", .{tval}),
            6 => std.debug.panic("Store/AMO Address Misaligned at 0x{x}", .{tval}),
            7 => std.debug.panic("Store/AMO Access Fault at 0x{x}", .{tval}),
            8 => {
                lib.info("Environment Call from U-Mode", .{});
                saved_sepc.* = epc + getInstructionStep(epc);
            },
            9 => {
                lib.info("Environment Call from S-Mode", .{});
                saved_sepc.* = epc + getInstructionStep(epc);
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
export fn userTrapHandler(frame: *user.TrapFrame) void {
    const cause = csr.read(.scause);
    const is_interrupt = (cause & SSTATUS_INTERRUPT_BIT) != 0;
    const exception_code = cause & ~SSTATUS_INTERRUPT_BIT;

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

    switch (frame.a7) {
        constants.SYS_EXIT => {
            lib.info("User task exited.", .{});
            lib.drainLogs();
            @panic("User Mode Ended.");
        },

        constants.SYS_WRITE => {
            lib.info("User task writing...", .{});
            lib.drainLogs();

            frame.a0 = 0; // return value
            frame.sepc += 4; // ecall is 4 bytes
        },

        constants.SYS_READ => {
            lib.info("User task reading...", .{});
            lib.drainLogs();

            frame.a0 = 0; // return value
            frame.sepc += 4; // ecall is 4 bytes
        },

        else => {
            lib.err("Unknown syscall: {}", .{frame.a7});
            lib.drainLogs();
            @panic("Unknown user syscall.");
        },
    }
}

inline fn getInstructionStep(epc: usize) usize {
    // Decode instruction length:
    // compressed instruction: 16-bit
    // standard instruction  : 32-bit
    const instruction = @as(*volatile u16, @ptrFromInt(epc)).*;
    return if ((instruction & 0b11) == 0b11) 4 else 2;
}
