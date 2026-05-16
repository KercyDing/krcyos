const constants = @import("constants");
const sbi = @import("sbi.zig");
const csr = @import("csr.zig");

pub var ticks: u64 = 0;

pub fn getTime() u64 {
    return asm volatile ("csrr %[ret], time"
        : [ret] "=r" (-> u64),
    );
}

pub fn init() void {
    setNextTick(constants.TICK_1MS * 10); // 10 ms
    enable();
}

pub fn setNextTick(interval: u64) void {
    const next_time = getTime() + interval;
    sbi.setTimer(next_time);
}

pub fn enable() void {
    csr.setBits(.sie, 0x20);
    csr.setBits(.sstatus, 0x02);
}

pub fn tick(interval: u64) void {
    ticks += 1;
    setNextTick(interval);
}
