const config = @import("config");

/// Put a char to console
pub fn consolePutchar(char: u8) void {
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

/// Shutdown the kernel
pub fn shutdown(failure: bool) noreturn {
    if (config.board == .qemu_virt) {
        poweroffQemu(failure);
    } else {
        poweroffSbi(failure);
    }
}

/// Poweroff QEMU
fn poweroffQemu(failure: bool) noreturn {
    const QEMU_TEXT_ADDT: *volatile u32 = @ptrFromInt(0x100000);
    QEMU_TEXT_ADDT.* = if (failure) 0x3333 else 0x5555;

    while (true) {}
}

/// Poweroff SBI
fn poweroffSbi(failure: bool) noreturn {
    const SBI_EXT_SRST: usize = 0x53525354;
    const RESET_TYPE_POWEROFF: usize = 0;
    const reason: usize = if (failure) 1 else 0;

    asm volatile ("ecall"
        : // no output need
        : [eid] "{a7}" (SBI_EXT_SRST),
          [fid] "{a6}" (0),
          [type] "{a0}" (RESET_TYPE_POWEROFF),
          [reason] "{a1}" (reason)
    );

    while (true) {}
}
