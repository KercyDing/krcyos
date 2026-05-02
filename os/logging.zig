const std = @import("std");
const console = @import("console.zig");

const Level = enum {
    debug,
    info,
    warn,
    err,

    fn color(self: Level) []const u8 {
        return switch (self) {
            .debug => "\x1b[32m",  // Green
            .info => "\x1b[34m",   // Blue
            .warn => "\x1b[93m",   // Yellow
            .err => "\x1b[31m",    // Red
        };
    }
};

pub const debug = makeLog(.debug);
pub const info  = makeLog(.info);
pub const warn  = makeLog(.warn);
pub const err   = makeLog(.err);

/// Prints log plus a trailing newline to the SBI console with level.
fn makeLog(comptime level: Level) fn(comptime []const u8, anytype) void {  // I generate the func
    return struct {
        fn wrapper(comptime fmt: []const u8, args: anytype) void {
            const prefix = level.color();
            const label = switch (level) {
                .debug => "Debug",
                .info  => "Info ",
                .warn  => "Warn ",
                .err => "Error",
            };
            console.print("{s}[{s}]\x1b[0m ", .{ prefix, label });
            console.print(fmt ++ "\n", args);
        }
    }.wrapper;
}
