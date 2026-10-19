test {
    const std = @import("std");

    std.testing.refAllDecls(@import("lib"));
}
