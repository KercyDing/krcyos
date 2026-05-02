const config = @import("config");
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

/// Prints debug log plus a trailing newline to the SBI console.
pub const debug = makeLog(.debug);

/// Prints info log plus a trailing newline to the SBI console.
pub const info = makeLog(.info);

/// Prints warn log plus a trailing newline to the SBI console.
pub const warn = makeLog(.warn);

/// Prints err log plus a trailing newline to the SBI console.
pub const err = makeLog(.err);

// Generate the log functions
fn makeLog(comptime level: Level) fn(comptime []const u8, anytype) void {
    return struct {
        fn wrapper(comptime fmt: []const u8, args: anytype) void {
            comptime {
                for (fmt) |char| {
                    if (char == '\n') {
                        @compileError("Log format string must NOT contain '\\n'.");
                    }
                }
            }

            if (@intFromEnum(level) < @intFromEnum(config.log)) return;

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
