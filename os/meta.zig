const constants = @import("constants.zig");

pub var region: MetaRegion linksection(".bss.meta") = undefined;

// Global metadata region. Holds bitmaps and other flags.
pub const MetaRegion = struct {
    heap_bitmaps: HeapBitmaps,
};

// Per-order bitmaps for the heap allocator.
pub const HeapBitmaps = [constants.HEAP_ORDER_COUNT][constants.HEAP_MAX_BM_BYTES]u8;

/// Set the bit at index `i` in the bitmap.
pub inline fn setBit(bitmap: []u8, i: usize) void {
    bitmap[i / 8] |= @as(u8, 1) << @intCast(i % 8);
}

/// Clear the bit at index `i` in the bitmap.
pub inline fn clearBit(bitmap: []u8, i: usize) void {
    bitmap[i / 8] &= ~(@as(u8, 1) << @intCast(i % 8));
}

/// Return true if the bit at index `i` is set.
pub inline fn testBit(bitmap: []u8, i: usize) bool {
    return (bitmap[i / 8] >> @intCast(i % 8)) & 1 == 1;
}
