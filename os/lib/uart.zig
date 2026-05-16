const constants = @import("constants");

const LSR_TX_IDLE: u8 = 0x20;

const RHR: usize = 0; // Receive Holding Register
const THR: usize = 0; // Transmit Holding Register
const IER: usize = 1; // Interrupt Enable Register
const FCR: usize = 2; // FIFO Control Register
const LCR: usize = 3; // Line Control Register
const LSR: usize = 5; // Line Status Register

const DLL: usize = 0; // Divisor Latch Low
const DLM: usize = 1; // Divisor Latch High

/// Initialize the UART chip (NS16550A).
pub fn init() void {
    const base = constants.UART_BASE;

    const ier_ptr: *volatile u8 = @ptrFromInt(base + IER);
    ier_ptr.* = 0x00;

    const lcr_ptr: *volatile u8 = @ptrFromInt(base + LCR);
    lcr_ptr.* = 0x80;

    const dll_ptr: *volatile u8 = @ptrFromInt(base + DLL);
    dll_ptr.* = 0x03;
    const dlm_ptr: *volatile u8 = @ptrFromInt(base + DLM);
    dlm_ptr.* = 0x00;

    lcr_ptr.* = 0x03;

    const fcr_ptr: *volatile u8 = @ptrFromInt(base + FCR);
    fcr_ptr.* = 0x07;
}

/// Put a char to console with UART.
pub fn putchar(char: u8) void {
    const lsr_ptr: *volatile u8 = @ptrFromInt(constants.UART_BASE + LSR);
    const thr_ptr: *volatile u8 = @ptrFromInt(constants.UART_BASE + THR);

    while ((lsr_ptr.* & LSR_TX_IDLE) == 0) {
        // Busy-wait
    }

    thr_ptr.* = char;
}
