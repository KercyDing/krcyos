const std = @import("std");

/// MSB of scause: 1 = interrupt, 0 = synchronous exception.
pub const SCAUSE_INTERRUPT_BIT: usize = @as(usize, 1) << (@bitSizeOf(usize) - 1);

/// sstatus.SIE: global supervisor interrupt enable.
pub const SSTATUS_SIE: usize = @as(usize, 1) << 1;

/// sstatus.SPP: previous privilege mode, 1 = S-mode.
pub const SSTATUS_SPP: usize = @as(usize, 1) << 8;

/// sstatus.SUM: permit S-mode access to U-mode pages.
pub const SSTATUS_SUM: usize = @as(usize, 1) << 18;

/// sie.STIE: supervisor timer interrupt enable.
pub const SIE_STIE: usize = @as(usize, 1) << 5;

pub const CsrReg = enum {
    stvec,
    sepc,
    scause,
    sstatus,
    stval,
    sscratch,
    satp,
    sie,
    time,
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

/// Invalidate all TLB entries.
pub inline fn sfenceVma() void {
    asm volatile ("sfence.vma" ::: .{ .memory = true });
}

/// Enable WFI("Wait For Interrupt") Mode.
/// WFI can reduce CPU power consumption.
pub inline fn wfi() void {
    asm volatile ("wfi");
}

/// Enable global interrupts.
pub inline fn enableInterrupts() void {
    const asm_template = std.fmt.comptimePrint("csrsi sstatus, {d}", .{SSTATUS_SIE});
    asm volatile (asm_template ::: .{ .memory = true });
}

/// Disable global interrupts.
pub inline fn disableInterrupts() void {
    const asm_template = std.fmt.comptimePrint("csrci sstatus, {d}", .{SSTATUS_SIE});
    asm volatile (asm_template ::: .{ .memory = true });
}

/// Halt the CPU permanently.
pub fn halt() noreturn {
    disableInterrupts();

    while (true) wfi();
}
