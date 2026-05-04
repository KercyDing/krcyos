const std = @import("std");
const log = @import("logging.zig");

pub const PAGE_SIZE: usize = 4096;
pub const physical_mem_end: usize = 0x88000000;

const Page = struct {
    next: ?*Page,
};
var free_list_head: ?*Page = null;
extern var ekernel: u8;

/// Initializes the Physical Memory Manager (PMM).
pub fn init() void {
    const kernel_end_addr = @intFromPtr(&ekernel);

    var current_addr = std.mem.alignForward(usize, kernel_end_addr, PAGE_SIZE);

    var page_count: usize = 0;

    while (current_addr + PAGE_SIZE <= physical_mem_end) {
        free(current_addr);
        current_addr += PAGE_SIZE;
        page_count += 1;
    }
    log.debug("PMM initialized. Free pages: {}", .{page_count});
}

/// Allocates a 4KB physical memory page.
/// Returns the physical address of the page, or `null` if OOM.
pub fn alloc() ?usize {
    const page = free_list_head orelse {
        log.warn("PMM: Out of memory!", .{});
        return null;
    };

    free_list_head = page.next;
    const physical_addr = @intFromPtr(page);
    const memory_slice: [*]u8 = @ptrCast(page);
    @memset(memory_slice[0..PAGE_SIZE], 0);

    return physical_addr;
}

/// Frees a 4KB physical memory page.
/// Panics if `physical_addr` is not 4KB aligned.
pub fn free(physical_addr: usize) void {
    if (physical_addr % PAGE_SIZE != 0) {
        @panic("PMM: Free address not aligned!");
    }
    const page: *Page = @ptrFromInt(physical_addr);

    page.next = free_list_head;
    free_list_head = page;
}
