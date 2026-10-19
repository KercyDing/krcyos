pub extern var stext: u8;
pub extern var etext: u8;
pub extern var srodata: u8;
pub extern var erodata: u8;
pub extern var sdata: u8;
pub extern var edata: u8;

// Bare metal environment and stack
pub extern var sbss: u8;
pub extern var ebss: u8;
pub extern var boot_stack_top: u8;
pub extern var ekernel: u8;
pub extern var suser: u8;
pub extern var euser: u8;
pub extern var suser_stack: u8;
pub extern var euser_stack: u8;
