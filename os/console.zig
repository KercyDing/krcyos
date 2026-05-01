const std = @import("std");
const sbi = @import("sbi.zig");

const Writer = std.Io.Writer;

/// Prints formatted text to the SBI console.
pub fn print(comptime fmt: []const u8, args: anytype) void {
    var writer: Writer = .{
        .vtable = &.{ .drain = drain },
        .buffer = &.{},
    };

    writer.print(fmt, args) catch unreachable;
}

/// Prints formatted text plus a trailing newline to the SBI console.
pub fn println(comptime fmt: []const u8, args: anytype) void {
    print(fmt, args);
    sbi.consolePutchar('\n');
}

fn drain(writer: *Writer, data: []const []const u8, splat: usize) Writer.Error!usize {
    writeBytes(writer.buffered());
    writer.end = 0;

    var written: usize = 0;
    for (data[0 .. data.len - 1]) |bytes| {
        writeBytes(bytes);
        written += bytes.len;
    }

    const repeated = data[data.len - 1];
    for (0..splat) |_| {
        writeBytes(repeated);
        written += repeated.len;
    }

    return written;
}

fn writeBytes(bytes: []const u8) void {
    for (bytes) |byte| {
        sbi.consolePutchar(byte);
    }
}
