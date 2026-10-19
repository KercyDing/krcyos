// ========== Page ==========
/// Page size in bytes (4 KB).
pub const PAGE_SIZE: usize = 4096;

// ========== Heap ==========
/// Total heap size in bytes (64 KB).
pub const HEAP_SIZE: usize = PAGE_SIZE * 16;
/// Minimum heap block size in bytes.
pub const HEAP_MIN_BLOCK_SIZE: usize = 16;
/// Number of heap free-list orders.
pub const HEAP_ORDER_COUNT: usize = 9;
/// Heap bitmap size in bytes (512 B).
pub const HEAP_MAX_BM_BYTES: usize = HEAP_SIZE / HEAP_MIN_BLOCK_SIZE / 8;

// ========== DRAM ==========
/// Start address of physical DRAM.
pub const DRAM_START: usize = 0x8000_0000;
/// Size of physical DRAM in bytes (128 MB).
pub const DRAM_SIZE: usize = 128 * 1024 * 1024;
/// End address of physical DRAM.
pub const DRAM_END: usize = DRAM_START + DRAM_SIZE;

// ========== UART ==========
/// Base address of the UART MMIO region.
pub const UART_BASE: usize = 0x1000_0000;

// ========== Logging ==========
/// Maximum length of a log message in bytes.
pub const LOG_MSG_MAX_LEN: usize = 128;
/// Capacity of the log queue.
pub const LOG_QUEUE_CAPACITY: usize = 64;

// ========== Timer ==========
/// Timer ticks per second (10 MHz on QEMU virt).
pub const TIMER_CLOCK_FREQ: u64 = 10_000_000;
/// Timer ticks per millisecond.
pub const TIMER_TICKS_PER_MS: u64 = @divExact(TIMER_CLOCK_FREQ, 1000);

// ========== Tasks ==========
/// Maximum number of tasks.
pub const TASK_MAX_COUNT: usize = 16;
/// Size of each task stack in bytes (8 KB).
pub const TASK_STACK_SIZE: usize = 1024 * 8;
