const std = @import("std");

pub const CsrReg = enum {
    stvec,
    sepc,
    scause,
    sstatus,
    stval,
    sscratch,
    satp,
    sie,
    // ...perhaps add later
};

/// Read usize value from specific registers.
pub inline fn read(comptime reg: CsrReg) usize {
    var value: usize = undefined;
    const asm_template = std.fmt.comptimePrint("csrr %[v], {s}", .{@tagName(reg)});
    asm volatile (asm_template
        : [v] "=r" (value),
    );

    return value;
}

/// Write usize value to specific registers.
pub inline fn write(comptime reg: CsrReg, value: usize) void {
    const asm_template = std.fmt.comptimePrint("csrw {s}, %[v]", .{@tagName(reg)});
    asm volatile (asm_template
        :
        : [v] "r" (value),
    );
}

/// Set a bit to 1 from specific registers with mask.
pub inline fn setBits(comptime reg: CsrReg, mask: usize) void {
    const asm_template = std.fmt.comptimePrint("csrs {s}, %[v]", .{@tagName(reg)});
    asm volatile (asm_template
        :
        : [v] "r" (mask),
    );
}

/// Clear a bit to 0 from specific registers with mask.
pub inline fn clearBits(comptime reg: CsrReg, mask: usize) void {
    const asm_template = std.fmt.comptimePrint("csrc {s}, %[v]", .{@tagName(reg)});
    asm volatile (asm_template
        :
        : [v] "r" (mask),
    );
}

/// Enable WFI("Wait For Interrupt") Mode.
/// WFI can reduce CPU power consumption.
pub inline fn wfi() void {
    while (true) {
        asm volatile ("wfi");
    }
}
