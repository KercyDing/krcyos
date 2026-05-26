const std = @import("std");
const builtin = @import("builtin");
const log = @import("logging.zig");

/// Custom assert function.
/// Return the name of the file and the line number then panic.
pub fn assert(ok: bool, src: std.builtin.SourceLocation) void {
    if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
        if (!ok) {
            @branchHint(.cold);
            log.err("Location: {s}:{}", .{ src.file, src.line });
            @panic("Unknown Assertion Error");
        }
    } else {
        if (!ok) unreachable;
    }
}

/// Custom assert function with msg.
/// Return the name of the file and the line number then panic.
pub fn assertMsg(ok: bool, comptime msg: []const u8, src: std.builtin.SourceLocation) void {
    if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
        if (!ok) {
            @branchHint(.cold);
            log.err("Location: {s}:{}", .{ src.file, src.line });
            @panic(std.fmt.comptimePrint("Err: {s}", .{msg}));
        }
    } else {
        if (!ok) unreachable;
    }
}
