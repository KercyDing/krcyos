const config = @import("config");

/// Shutdown the kernel.
pub fn shutdown(failure: bool) noreturn {
    switch (config.board) {
        .qemu_virt => poweroffQemu(failure),
        .real_board => poweroffSbi(failure),
    }
}

/// Poweroff QEMU.
fn poweroffQemu(failure: bool) noreturn {
    const QEMU_TEXT_ADDT: *volatile u32 = @ptrFromInt(0x100000);
    QEMU_TEXT_ADDT.* = if (failure) 0x3333 else 0x5555;

    while (true) {}
}

/// Poweroff SBI.
fn poweroffSbi(failure: bool) noreturn {
    const reason: usize = if (failure) 1 else 0;
    _ = sbiCall(0x53525354, 0, 0, reason, 0);

    while (true) {}
}

pub fn setTimer(stime_value: u64) void {
    _ = sbiCall(0x54494D45, 0, stime_value, 0, 0);
}

inline fn sbiCall(eid: usize, fid: usize, arg0: usize, arg1: usize, arg2: usize) usize {
    return asm volatile ("ecall"
        : [ret] "={a0}" (-> usize),
        : [eid] "{a7}" (eid),
          [fid] "{a6}" (fid),
          [arg0] "{a0}" (arg0),
          [arg1] "{a1}" (arg1),
          [arg2] "{a2}" (arg2),
    );
}
