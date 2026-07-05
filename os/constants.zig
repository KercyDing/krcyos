// Page
pub const PAGE_SIZE: usize = 4096; // 4 KB

// Heap
pub const HEAP_SIZE: usize = PAGE_SIZE * 16; // 64 KB
pub const HEAP_MIN_BLOCK_SIZE: usize = 16;
pub const HEAP_ORDER_COUNT: usize = 9;
pub const HEAP_MAX_BM_BYTES: usize = HEAP_SIZE / HEAP_MIN_BLOCK_SIZE / 8; // 512 B

// DRAM
pub const DRAM_START: usize = 0x8000_0000;
pub const DRAM_SIZE: usize = 128 * 1024 * 1024; // 128 MB
pub const DRAM_END: usize = DRAM_START + DRAM_SIZE; // 0x8800_0000

// UART
pub const UART_BASE: usize = 0x1000_0000;

// Logging
pub const LOG_MSG_MAX_LEN: usize = 128;
pub const LOG_QUEUE_CAPACITY: usize = 64;

// Timer
pub const TIMER_CLOCK_FREQ: u64 = 10_000_000; // 1 s
pub const TIMER_TICK_1S: u64 = TIMER_CLOCK_FREQ; // 1 s
pub const TIMER_TICK_1MS: u64 = TIMER_CLOCK_FREQ / 1000; // 1 ms

// Tasks
pub const TASK_MAX_COUNT: usize = 16;
pub const TASK_STACK_SIZE: usize = 1024 * 8;

// Syscall
pub const SYS_EXIT: usize = 0;
pub const SYS_READ: usize = 1;
pub const SYS_WRITE: usize = 2;
