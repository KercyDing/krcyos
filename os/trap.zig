const std = @import("std");
const csr = @import("csr.zig");
const log = @import("logging.zig");

const save_regs = blk: {
    var res: []const u8 = "";
    for (1..32) |i| {
        res = res ++ std.fmt.comptimePrint("sd x{d}, {d}*8(sp)\n", .{ i, i });
    }
    break :blk res;
};

const restore_regs = blk: {
    var res: []const u8 = "";
    for (1..32) |i| {
        res = res ++ std.fmt.comptimePrint("ld x{d}, {d}*8(sp)\n", .{ i, i });
    }
    break :blk res;
};

pub fn init() void {
    csr.write(.stvec, @intFromPtr(&trapEntry));
}

export fn trapEntry() align(4) callconv(.naked) noreturn {
    asm volatile (
        "addi sp, sp, -256\n" ++
        save_regs ++
        "call trapHandler\n" ++
        restore_regs ++
        "addi sp, sp, 256\n" ++
        "sret\n"
    );
}

export fn trapHandler() void {
    const cause = csr.read(.scause);
    const epc = csr.read(.sepc);
    const tval = csr.read(.stval);

    const flag: u1 = @truncate(cause >> 63);
    const exception_code = cause & ~(@as(usize, 1) << 63);

    const instruction = @as(*volatile u16, @ptrFromInt(epc)).*;
    const step: usize = if ((instruction & 0b11) == 0b11) 4 else 2;  // check if compressed

    switch (flag) {
        0 => switch (exception_code) {  // sync exception
            0 => std.debug.panic("Instruction Address Misaligned at 0x{x}", .{tval}),
            1 => std.debug.panic("Instruction Access Fault at 0x{x}", .{tval}),
            2 => std.debug.panic("Illegal Instruction at 0x{x}", .{epc}),
            3 => {
                log.warn("Breakpoint Exception at 0x{x}", .{epc});
                csr.write(.sepc, epc + step);
            },
            4 => std.debug.panic("Load Address Misaligned at 0x{x}", .{tval}),
            5 => std.debug.panic("Load Access Fault at 0x{x}", .{tval}),
            6 => std.debug.panic("Store/AMO Address Misaligned at 0x{x}", .{tval}),
            7 => std.debug.panic("Store/AMO Access Fault at 0x{x}", .{tval}),
            8 => {
                log.info("Environment Call from U-Mode", .{});
                csr.write(.sepc, epc + step);
            },
            9 => {
                log.info("Environment Call from S-Mode", .{});
                csr.write(.sepc, epc + step);
            },
            12 => std.debug.panic("Instruction Page Fault at 0x{x}", .{tval}),
            13 => std.debug.panic("Load Page Fault at 0x{x}", .{tval}),
            15 => std.debug.panic("Store/AMO Page Fault at 0x{x}", .{tval}),
            else => std.debug.panic("Unhandled Exception: {} at 0x{x}, tval: 0x{x}", .{ exception_code, epc, tval }),
        },
        1 => switch (exception_code) {  // asynchronous interrupt
            1 => log.info("Supervisor Software Interrupt", .{}),
            5 => log.info("Supervisor Timer Interrupt", .{}),
            9 => log.info("Supervisor External Interrupt", .{}),
            else => log.warn("Unknown Interrupt: {}", .{exception_code}),
        },
    }
}
