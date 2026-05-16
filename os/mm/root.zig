//! os/mm/root.zig
pub const heap = @import("heap.zig");
pub const meta = @import("meta.zig");
pub const pmm = @import("pmm.zig");
pub const vmm = @import("vmm.zig");

pub fn init() void {
    pmm.init();
    vmm.init();
}
