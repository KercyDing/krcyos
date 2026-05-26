const constants = @import("constants");
const sbi = @import("sbi.zig");
const csr = @import("csr.zig");

pub var ticks: u64 = 0;

/// Get the current mtime of CPU.
pub fn getTime() u64 {
    return asm volatile ("csrr %[ret], time"
        : [ret] "=r" (-> u64),
    );
}

/// Initialize the timer module.
/// Set the first tick for 10 ms, then enable interrupts.
pub fn init() void {
    setNextTick(constants.TIMER_TICK_1MS * 10); // 10 ms
    enable();
}

/// Set the next tick with the given interval.
pub fn setNextTick(interval: u64) void {
    const next_time = getTime() + interval;
    sbi.setTimer(next_time);
}

/// Enable the timer interrupt.
pub fn enable() void {
    csr.setBits(.sie, 0x20); // enable timer interrupt
    csr.setBits(.sstatus, 0x02); // open the global interrupt gate
}

/// Tick processing function for trapHandler.
pub fn tick(interval: u64) void {
    ticks += 1;
    setNextTick(interval);
}
