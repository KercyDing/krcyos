pub fn print(string: []const u8) void {
    for (string) |char| {
        consolePutchar(char);
    }
}

pub fn println(string: []const u8) void {
    for (string) |char| {
        consolePutchar(char);
    }
    consolePutchar('\n');
}

fn consolePutchar(char: u8) void {
    // Yes, if you write it in pure asm, it would be like:
    //
    // li a7, 1
    // li a6, 0
    // ecall
    // ret
    //
    _ = asm volatile ("ecall"
        : [ret] "={a0}" (-> usize)
        : [eid] "{a7}" (0x01),
          [fid] "{a6}" (0),
          [arg0] "{a0}" (char)
    );
}
