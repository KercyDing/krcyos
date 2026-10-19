const std = @import("std");

extern const suser: u8;
extern const euser: u8;
extern const suser_stack: u8;
extern const euser_stack: u8;

fn isRangeInside(addr: usize, len: usize, start: usize, end: usize) bool {
    if (len == 0) return true;

    const range_end = std.math.add(usize, addr, len) catch return false;

    return addr >= start and range_end <= end;
}

pub fn isUserRange(addr: usize, len: usize) bool {
    const user_start = @intFromPtr(&suser);
    const user_end = @intFromPtr(&euser);

    const user_stack_start = @intFromPtr(&suser_stack);
    const user_stack_end = @intFromPtr(&euser_stack);

    return isRangeInside(addr, len, user_start, user_end) or
        isRangeInside(addr, len, user_stack_start, user_stack_end);
}
