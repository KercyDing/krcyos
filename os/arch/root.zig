//! os/arch/root.zig

pub const context = @import("context.zig");
pub const csr = @import("csr.zig");
pub const sbi = @import("sbi.zig");
pub const timer = @import("timer.zig");

pub const TaskContext = context.TaskContext;

pub const wfi = csr.wfi;
pub const halt = csr.halt;
