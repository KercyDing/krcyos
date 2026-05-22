//! os/lib/root.zig
pub const console = @import("console.zig");
pub const log = @import("logging.zig");
pub const uart = @import("uart.zig");

pub const assert = log.assert;
pub const assertMsg = log.assertMsg;
