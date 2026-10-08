test {
    const std = @import("std");

    std.testing.refAllDecls(@import("ipc/spsc.zig"));
    std.testing.refAllDecls(@import("lib/log_queue.zig"));
}
