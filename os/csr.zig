const std = @import("std");

pub const CsrReg = enum {
    stvec,
    sepc,
    scause,
    sstatus,
    stval,
    sscratch,
    satp,
    // ...perhaps add later
};

/// Read usize value from specific registers.
pub inline fn read(comptime reg: CsrReg) usize {
    var value: usize = undefined;
    const asm_template = std.fmt.comptimePrint("csrr %[v], {s}", .{@tagName(reg)});
    asm volatile (asm_template : [v] "=r" (value));

    return value;
}

/// Write usize value to specific registers.
pub inline fn write(comptime reg: CsrReg, value: usize) void {
    const asm_template = std.fmt.comptimePrint("csrw {s}, %[v]", .{@tagName(reg)});
    asm volatile (asm_template : : [v] "r" (value));
}
