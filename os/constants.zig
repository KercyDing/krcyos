// Boot stack
pub const BOOT_STACK_SIZE: usize = 4096 * 4; // 16 KB

// Page
pub const PAGE_SIZE: usize = 4096; // 4 KB

// DRAM
pub const DRAM_START: usize = 0x8000_0000;
pub const DRAM_SIZE: usize = 128 * 1024 * 1024; // 128 MB
pub const DRAM_END: usize = DRAM_START + DRAM_SIZE; // 0x8800_0000

// UART
pub const UART_BASE = 0x1000_0000;
