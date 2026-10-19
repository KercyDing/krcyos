//! os/lib/root.zig

// console.zig
pub const console = @import("console.zig");

// uart.zig
pub const uart = @import("uart.zig");

// assert.zig
const assert_mod = @import("assert.zig");
pub const assert = assert_mod.assert;
pub const assertMsg = assert_mod.assertMsg;

// logging.zig
const logging_mod = @import("logging.zig");
pub const debug = logging_mod.debug;
pub const info = logging_mod.info;
pub const warn = logging_mod.warn;
pub const err = logging_mod.err;
pub const drainLogs = logging_mod.drain;

// spsc.zig
pub const spsc = @import("spsc.zig");
