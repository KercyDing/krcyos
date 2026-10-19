//! os/abi/root.zig

pub const frame = @import("frame.zig");
pub const linker = @import("linker.zig");
pub const syscall = @import("syscall.zig");

pub const TrapFrame = frame.TrapFrame;
