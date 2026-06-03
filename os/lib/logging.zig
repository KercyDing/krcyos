const std = @import("std");
const config = @import("config");
const constants = @import("constants");
const console = @import("console.zig");
const log_record = @import("log_record.zig");
const Level = log_record.Level;
const LogRecord = log_record.LogRecord;
const LogQueue = @import("log_queue.zig").LogQueue;

var queue = LogQueue(constants.LOG_QUEUE_CAPACITY).init();
var dropped_logs: usize = 0;

/// Print debug log plus a trailing newline to the SBI console.
pub const debug = makeLogFn(.debug);

/// Print info log plus a trailing newline to the SBI console.
pub const info = makeLogFn(.info);

/// Print warn log plus a trailing newline to the SBI console.
pub const warn = makeLogFn(.warn);

/// Print err log plus a trailing newline to the SBI console.
pub const err = makeLogFn(.err);

// Generate the log functions.
fn makeLogFn(comptime level: Level) fn (comptime []const u8, anytype) void {
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

            const record: LogRecord = makeLogRecord(level, fmt, args);
            pushLogRecord(record);
        }
    }.wrapper;
}

/// Generate the log record.
fn makeLogRecord(comptime level: Level, comptime fmt: []const u8, args: anytype) LogRecord {
    var record: LogRecord = undefined;
    var writer: std.Io.Writer = .fixed(&record.msg);

    writer.print(fmt, args) catch |write_err| switch (write_err) {
        error.WriteFailed => {},
    };

    const message = writer.buffered();
    record.level = level;
    record.timestamp = 0;
    record.length = message.len;

    return record;
}

/// Push the log record into the log queue.
fn pushLogRecord(record: LogRecord) void {
    if (!queue.tryPush(record)) {
        _ = @atomicRmw(usize, &dropped_logs, .Add, 1, .monotonic);
    }
}

/// Drain the log queue.
pub fn drain() void {
    const dropped = @atomicRmw(usize, &dropped_logs, .Xchg, 0, .acquire);
    if (dropped != 0) {
        console.print("{s}[{s}]\x1b[0m dropped {} log records\n", .{
            Level.warn.color(),
            Level.warn.label(),
            dropped,
        });
    }

    while (queue.pop()) |record| {
        console.print("{s}[{s}]\x1b[0m {s}\n", .{
            record.level.color(),
            record.level.label(),
            record.msg[0..record.length],
        });
    }
}
