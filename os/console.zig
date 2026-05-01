const sbi = @import("sbi.zig");

pub fn print(string: []const u8) void {
    for (string) |char| {
        sbi.consolePutchar(char);
    }
}

pub fn println(string: []const u8) void {
    for (string) |char| {
        sbi.consolePutchar(char);
    }
    sbi.consolePutchar('\n');
}
