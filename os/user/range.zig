const std = @import("std");

const abi = @import("abi");

const linker = abi.linker;

fn isRangeInside(addr: usize, len: usize, start: usize, end: usize) bool {
    if (len == 0) return true;

    const range_end = std.math.add(usize, addr, len) catch return false;

    return addr >= start and range_end <= end;
}

pub fn isUserRange(addr: usize, len: usize) bool {
    const user_start = @intFromPtr(&linker.suser);
    const user_end = @intFromPtr(&linker.euser);

    const user_stack_start = @intFromPtr(&linker.suser_stack);
    const user_stack_end = @intFromPtr(&linker.euser_stack);

    return isRangeInside(addr, len, user_start, user_end) or
        isRangeInside(addr, len, user_stack_start, user_stack_end);
}
