const config = @import("config");
const console = @import("console.zig");
const Level = @import("log_record.zig").Level;

/// Print debug log plus a trailing newline to the SBI console.
pub const debug = makeLog(.debug);

/// Print info log plus a trailing newline to the SBI console.
pub const info = makeLog(.info);

/// Print warn log plus a trailing newline to the SBI console.
pub const warn = makeLog(.warn);

/// Print err log plus a trailing newline to the SBI console.
pub const err = makeLog(.err);

// Generate the log functions
fn makeLog(comptime level: Level) fn (comptime []const u8, anytype) void {
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
            const label = Level.label(level);
            console.print("{s}[{s}]\x1b[0m ", .{ prefix, label });
            console.print(fmt ++ "\n", args);
        }
    }.wrapper;
}
