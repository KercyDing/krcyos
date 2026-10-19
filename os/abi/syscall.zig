// Syscall
pub const SYS_EXIT: usize = 0;
pub const SYS_WRITE: usize = 1;
pub const SYS_READ: usize = 2;

pub const RET_ERR: usize = @bitCast(@as(isize, -1));
