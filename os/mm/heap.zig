const HeapAllocator = @This();

const std = @import("std");
const meta = @import("meta.zig");
const constants = @import("../constants.zig");
const log = @import("../lib/logging.zig");
const assert = log.assert;

const Node = struct {
    next: ?*Node,
};

free_lists: [constants.HEAP_ORDER_COUNT]?*Node,
heap_start: usize,

/// Initialize the Heap Allocator.
pub fn init(start: usize) HeapAllocator {
    assert(start % constants.PAGE_SIZE == 0, @src());

    var instance = HeapAllocator{
        .free_lists = [_]?*Node{null} ** constants.HEAP_ORDER_COUNT,
        .heap_start = start,
    };

    const block_nums = constants.HEAP_SIZE / constants.PAGE_SIZE;
    var curr_addr = start;
    for (0..block_nums) |_| {
        const node_ptr: *Node = @ptrFromInt(curr_addr);
        node_ptr.next = instance.free_lists[constants.HEAP_ORDER_COUNT - 1];
        instance.free_lists[constants.HEAP_ORDER_COUNT - 1] = node_ptr;
        curr_addr += constants.PAGE_SIZE;
    }

    return instance;
}

/// Allocate a memory block of at least `requested_size`.
/// Return the address, or null if `OOM`.
pub fn alloc(self: *HeapAllocator, requested_size: usize) ?usize {
    if (requested_size == 0 or requested_size > constants.PAGE_SIZE) return null;

    const min_size = @max(requested_size, constants.HEAP_MIN_BLOCK_SIZE); // at least 16 here.
    const target_order = std.math.log2_int_ceil(usize, min_size) - 4; // get the order from size with ceil.
    var curr_order = target_order;

    while (curr_order < constants.HEAP_ORDER_COUNT) : (curr_order += 1) {
        if (self.free_lists[curr_order]) |node| { // if free_lists[curr_order] is not empty, we get it.
            self.free_lists[curr_order] = node.next;

            while (curr_order > target_order) {
                curr_order -= 1;

                const split_size = getBlockSize(curr_order);
                const buddy_addr = @intFromPtr(node) + split_size;
                const buddy_node: *Node = @ptrFromInt(buddy_addr);

                // Insert the buddy into the linked list.
                buddy_node.next = self.free_lists[curr_order];
                self.free_lists[curr_order] = buddy_node;
            }
            const addr: usize = @intFromPtr(node);
            const index = (addr - self.heap_start) / getBlockSize(target_order);
            meta.setBit(&meta.region.heap_bitmaps[target_order], index);
            return addr;
        }
    }
    return null;
}

/// Free a memory block and merge it with its buddy.
pub fn free(self: *HeapAllocator, addr: usize) void {
    assert(addr >= self.heap_start and addr < self.heap_start + constants.HEAP_SIZE, @src());

    // Find the order with bitmaps.
    var order_found: usize = 0;
    while (order_found < constants.HEAP_ORDER_COUNT) : (order_found += 1) {
        const index = (addr - self.heap_start) / getBlockSize(order_found);
        if (meta.testBit(&meta.region.heap_bitmaps[order_found], index)) {
            meta.clearBit(&meta.region.heap_bitmaps[order_found], index);
            break;
        }
    } else {
        @panic("Heap: free unknown address!");
    }
    const block_size = getBlockSize(order_found);
    assert(addr % block_size == 0, @src());

    var curr_addr = addr;
    var curr_order = order_found;

    while (curr_order < constants.HEAP_ORDER_COUNT - 1) {
        const buddy_addr = getBuddyAddress(curr_addr, curr_order);

        var prev_ptr: ?*Node = null;
        var curr_ptr = self.free_lists[curr_order];
        var buddy_found = false;

        // Find the buddy then delete it.
        while (curr_ptr) |curr_node| {
            if (@intFromPtr(curr_node) == buddy_addr) {
                if (prev_ptr) |p| {
                    p.next = curr_node.next;
                } else {
                    self.free_lists[curr_order] = curr_node.next;
                }
                buddy_found = true;
                break;
            }
            prev_ptr = curr_node;
            curr_ptr = curr_node.next;
        }

        if (!buddy_found) break; // buddy does not exist.

        // Combine and return the smaller address of the two.
        if (buddy_addr < curr_addr) {
            curr_addr = buddy_addr;
        }

        curr_order += 1;
    }

    const final_node: *Node = @ptrFromInt(curr_addr);
    final_node.next = self.free_lists[curr_order];
    self.free_lists[curr_order] = final_node;
}

/// Calculate the buddy block address for a given address and order.
inline fn getBuddyAddress(addr: usize, order: usize) usize {
    const block_size = getBlockSize(order);
    return addr ^ block_size; // reverse the specific bit
}

/// Calculate the size for a given order.
inline fn getBlockSize(order: usize) usize {
    return constants.HEAP_MIN_BLOCK_SIZE << @intCast(order);
}

const vtable = std.mem.Allocator.VTable{
    .alloc = allocImpl,
    .resize = std.mem.Allocator.noResize,
    .remap = std.mem.Allocator.noRemap,
    .free = freeImpl,
};

pub fn allocator(self: *HeapAllocator) std.mem.Allocator {
    return .{
        .ptr = self,
        .vtable = &vtable,
    };
}

fn allocImpl(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
    _ = alignment;
    _ = ret_addr;

    const heap_allocator: *HeapAllocator = @ptrCast(@alignCast(ctx));
    const addr = heap_allocator.alloc(len) orelse return null;
    return @ptrFromInt(addr);
}

fn freeImpl(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
    _ = alignment;
    _ = ret_addr;

    const heap_allocator: *HeapAllocator = @ptrCast(@alignCast(ctx));
    heap_allocator.free(@intFromPtr(memory.ptr));
}
