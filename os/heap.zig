const std = @import("std");
const constants = @import("constants.zig");
const log = @import("logging.zig");
const assert = log.assert;

const MIN_BLOCK_SIZE: usize = 16;
const ORDER_COUNT: usize = 9;

const Node = struct {
    next: ?*Node,
};

pub const HeapAllocator = struct {
    free_lists: [ORDER_COUNT]?*Node,
    heap_start: usize,
    heap_size: usize,
};

/// Initializes the Heap Allocator.
pub fn init(start: usize, size: usize) HeapAllocator {
    assert(start % constants.PAGE_SIZE == 0, @src());

    var instance = HeapAllocator{
        .free_lists = [_]?*Node{null} ** ORDER_COUNT,
        .heap_start = start,
        .heap_size = size,
    };

    const block_nums = size / constants.PAGE_SIZE;
    var curr_addr = start;
    for (0..block_nums) |_| {
        const node_ptr: *Node = @ptrFromInt(curr_addr);
        node_ptr.next = instance.free_lists[ORDER_COUNT - 1];
        instance.free_lists[ORDER_COUNT - 1] = node_ptr;
        curr_addr += constants.PAGE_SIZE;
    }

    return instance;
}

/// Allocates a memory block of at least `requested_size`.
/// Returns the address, or null if `OOM`.
pub fn alloc(self: *HeapAllocator, requested_size: usize) ?usize {
    if (requested_size == 0 or requested_size > constants.PAGE_SIZE) return null;

    const min_size = @max(requested_size, MIN_BLOCK_SIZE); // at least 16 here.
    const target_order = std.math.log2_int_ceil(usize, min_size) - 4; // get the order from size with ceil.
    var curr_order = target_order;

    while (curr_order < ORDER_COUNT) : (curr_order += 1) {
        if (self.free_lists[curr_order]) |node| { // if free_lists[curr_order] is not empty, we get it.
            self.free_lists[curr_order] = node.next;

            while (curr_order > target_order) {
                curr_order -= 1;

                const split_size = MIN_BLOCK_SIZE << @intCast(curr_order);
                const buddy_addr = @intFromPtr(node) + split_size;
                const buddy_node: *Node = @ptrFromInt(buddy_addr);

                // Insert the buddy into the linked list.
                buddy_node.next = self.free_lists[curr_order];
                self.free_lists[curr_order] = buddy_node;
            }
            return @intFromPtr(node);
        }
    }
    return null;
}

/// Frees a memory block and merge it with its buddy.
pub fn free(self: *HeapAllocator, addr: usize, order: usize) void {
    assert(addr >= self.heap_start and addr < self.heap_start + self.heap_size, @src());
    assert(order < ORDER_COUNT, @src());

    const block_size = MIN_BLOCK_SIZE << @intCast(order);
    assert(addr % block_size == 0, @src());

    var curr_addr = addr;
    var curr_order = order;

    while (curr_order < ORDER_COUNT - 1) {
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

/// Calculates the buddy block address for a given address and order.
fn getBuddyAddress(addr: usize, order: usize) usize {
    const block_size = MIN_BLOCK_SIZE << @intCast(order);
    return addr ^ block_size; // reverse the specific bit
}
