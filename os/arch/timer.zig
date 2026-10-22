const sbi = @import("sbi.zig");
const csr = @import("csr.zig");

pub var ticks: u64 = 0;

var period: u64 = 0;

/// Get the current mtime of CPU.
pub fn getTime() u64 {
    return @intCast(csr.read(.time));
}

/// Initialize the timer module with the given tick interval.
pub fn init(tick_interval: u64) void {
    period = tick_interval;
    setNextTick(period);
    enable();
}

/// Set the next tick with the given interval.
pub fn setNextTick(interval: u64) void {
    const next_time = getTime() + interval;
    sbi.setTimer(next_time);
}

/// Enable the timer interrupt.
pub fn enable() void {
    csr.setBits(.sie, csr.SIE_STIE); // enable timer interrupt
    csr.enableInterrupts(); // open the global interrupt gate
}

/// Tick processing function for trapHandler.
pub fn tick() void {
    ticks += 1;
    setNextTick(period);
}
