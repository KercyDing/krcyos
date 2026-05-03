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
            2 => @panic("Illegal Instruction!"),
            3 => {
                log.warn("Breakpoint Exception", .{});
                csr.write(.sepc, epc + step);
            },
            8, 9 => {
                log.warn("Syscall from U/S-Mode", .{});
                csr.write(.sepc, epc + step);
            },
            12 => std.debug.panic("Instruction Page Fault at 0x{x}", .{tval}),  // panic now
            13 => std.debug.panic("Load Page Fault at 0x{x}", .{tval}),  // panic now
            15 => std.debug.panic("Store Page Fault at 0x{x}", .{tval}),  // panic now
            else => std.debug.panic("Unhandled Exception: {} at 0x{x}", .{exception_code, epc}),  // panic now
        },
        1 => switch (exception_code) {  // asynchronous interrupt
            1 => log.warn("Supervisor Software Interrupt", .{}),
            5 => log.warn("Supervisor Timer Interrupt", .{}),
            9 => log.warn("Supervisor External Interrupt", .{}),
            else => log.warn("Unknown Interrupt: {}", .{exception_code}),
        },
    }
}
