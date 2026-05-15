const std = @import("std");
const constants = @import("constants.zig");
const log = @import("logging.zig");

const Page = struct {
    next: ?*Page,
};
var free_list_head: ?*Page = null;
extern var ekernel: u8;

/// Initialize the Physical Memory Manager (PMM).
pub fn init() void {
    const kernel_end_addr = @intFromPtr(&ekernel);

    var current_addr = std.mem.alignForward(usize, kernel_end_addr, constants.PAGE_SIZE);

    var page_count: usize = 0;

    while (current_addr + constants.PAGE_SIZE <= constants.DRAM_END) {
        free(current_addr);
        current_addr += constants.PAGE_SIZE;
        page_count += 1;
    }
    log.debug("PMM initialized. Free pages: {}", .{page_count});
}

/// Allocate a 4KB physical memory page.
/// Return the physical address of the page, or `null` if OOM.
pub fn alloc() ?usize {
    const page = free_list_head orelse {
        log.warn("PMM: Out of memory!", .{});
        return null;
    };

    free_list_head = page.next;
    const physical_addr = @intFromPtr(page);
    const memory_slice: [*]u8 = @ptrCast(page);
    @memset(memory_slice[0..constants.PAGE_SIZE], 0);

    return physical_addr;
}

/// Free a 4KB physical memory page.
/// Panic if `physical_addr` is not 4KB aligned.
pub fn free(physical_addr: usize) void {
    if (physical_addr % constants.PAGE_SIZE != 0) {
        @panic("PMM: Free address not aligned!");
    }
    const page: *Page = @ptrFromInt(physical_addr);

    page.next = free_list_head;
    free_list_head = page;
}
