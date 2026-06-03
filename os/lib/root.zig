//! os/lib/root.zig

// console.zig
pub const console = @import("console.zig");

// uart.zig
pub const uart = @import("uart.zig");

// assert.zig
pub const assert = @import("assert.zig").assert;
pub const assertMsg = @import("assert.zig").assertMsg;

// logging.zig
pub const debug = @import("logging.zig").debug;
pub const info = @import("logging.zig").info;
pub const warn = @import("logging.zig").warn;
pub const err = @import("logging.zig").err;
pub const drainLogs = @import("logging.zig").drain;
