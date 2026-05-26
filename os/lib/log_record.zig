const constants = @import("constants");

pub const Level = enum {
    debug,
    info,
    warn,
    err,

    pub fn color(self: Level) []const u8 {
        return switch (self) {
            .debug => "\x1b[32m", // Green
            .info => "\x1b[34m", // Blue
            .warn => "\x1b[93m", // Yellow
            .err => "\x1b[31m", // Red
        };
    }

    pub fn label(self: Level) []const u8 {
        return switch (self) {
            .debug => "Debug",
            .info => "Info ",
            .warn => "Warn ",
            .err => "Error",
        };
    }
};

pub const LogRecord = struct {
    level: Level,
    length: usize,
    timestamp: usize,
    msg: [constants.LOG_MSG_MAX_LEN]u8,
};
