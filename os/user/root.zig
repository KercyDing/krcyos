//! os/user/root.zig

pub const code = @import("code.zig");
pub const enter = @import("enter.zig");

const range = @import("range.zig");

pub const enterUser = enter.enterUser;
pub const userEntry = code.userEntry;
pub const isUserRange = range.isUserRange;
