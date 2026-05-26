const std = @import("std");
const constants = @import("constants");
const pmm = @import("pmm.zig");
const lib = @import("lib");

pub const PageTable = [512]PTE;
pub var root_table: *PageTable = undefined;

extern var stext: u8;
extern var etext: u8;
extern var srodata: u8;
extern var erodata: u8;
extern var sdata: u8;
extern var edata: u8;
extern var sbss: u8;
extern var ebss: u8;

// Regions Mapping
const regions = [_]struct {
    start: *u8,
    end: *u8,
    r: bool,
    w: bool,
    x: bool,
}{
    .{ .start = &stext, .end = &etext, .r = true, .w = false, .x = true }, // .text
    .{ .start = &srodata, .end = &erodata, .r = true, .w = false, .x = false }, // .rodata
    .{ .start = &sdata, .end = &edata, .r = true, .w = true, .x = false }, // .data
    .{ .start = &edata, .end = &ebss, .r = true, .w = true, .x = false }, // .bss & stack
    .{ .start = &ebss, .end = @ptrFromInt(constants.DRAM_END), .r = true, .w = true, .x = false }, // physical memory pool
    .{ .start = @ptrFromInt(constants.UART_BASE), .end = @ptrFromInt(constants.UART_BASE + constants.PAGE_SIZE), .r = true, .w = true, .x = false }, // UART
};

// Page Table Entry
pub const PTE = packed struct {
    V: bool, // Valid
    R: bool, // Read
    W: bool, // Write
    X: bool, // Execute
    U: bool, // User
    G: bool, // Global
    A: bool, // Accessed
    D: bool, // Dirty
    rsw: u2 = 0,
    ppn: u44, // Physical Page Number
    reserved: u7 = 0,
    pbmt: u2 = 0,
    n: bool = false,

    /// Level 0(Leaf)
    pub inline fn ppn0(self: PTE) u9 {
        return @truncate(self.ppn);
    }

    /// Level 1(Mid)
    pub inline fn ppn1(self: PTE) u9 {
        return @truncate(self.ppn >> 9);
    }

    /// Level 2(Root)
    pub inline fn ppn2(self: PTE) u26 {
        return @truncate(self.ppn >> 18);
    }
};

/// Initialize the Virtual Memory Manager (VMM).
pub fn init() void {
    // Create Root Table
    const root_table_pa = pmm.alloc() catch {
        @branchHint(.cold);
        @panic("VMM: Failed to allocate root table!");
    };
    root_table = @ptrFromInt(root_table_pa);
    @memset(std.mem.asBytes(root_table), 0);

    // Identity Mapping
    for (regions) |region| {
        var addr = @intFromPtr(region.start);
        const end_addr = @intFromPtr(region.end);

        while (addr < end_addr) : (addr += constants.PAGE_SIZE) {
            mapPage(root_table, addr, addr, region.r, region.w, region.x, false);
        }
    }

    const satp_value: usize = (@as(usize, 1) << 63) | (root_table_pa >> 12);

    asm volatile (
        \\ csrw satp, %[val]
        \\ sfence.vma
        :
        : [val] "r" (satp_value),
    );
}

/// Map a Virtual Address to a Physical Address in the provided root page table.
pub fn mapPage(root: *PageTable, va: usize, pa: usize, r: bool, w: bool, x: bool, u: bool) void {
    lib.assert(va % constants.PAGE_SIZE == 0, @src());
    lib.assert(pa % constants.PAGE_SIZE == 0, @src());

    var current_table = root;

    const levels = [2]u2{ 2, 1 };
    for (levels) |level| {
        const vpn = getVPN(va, level);
        var pte = &current_table[vpn];

        if (!pte.V) {
            const new_page_pa = pmm.alloc() catch {
                @branchHint(.cold);
                @panic("VMM: Out of memory!");
            };
            const new_page: *PageTable = @ptrFromInt(new_page_pa);
            @memset(std.mem.asBytes(new_page), 0);

            // Truncate pa to get real ppn then put into pte.
            pte.ppn = @truncate(new_page_pa >> 12);
            pte.V = true;
        }

        const next_pa = @as(usize, pte.ppn) << 12;
        current_table = @ptrFromInt(next_pa);
    }

    const vpn0 = getVPN(va, 0);
    var leaf_pte = &current_table[vpn0];

    leaf_pte.ppn = @truncate(pa >> 12);
    leaf_pte.V = true;
    leaf_pte.R = r;
    leaf_pte.W = w;
    leaf_pte.X = x;
    leaf_pte.U = u;
}

/// Get virtual page number for the given virtual address and level.
inline fn getVPN(va: usize, level: u2) usize { // SV39 needs 0, 1, 2 level
    // Obviously we only support SV39 here.
    // So "shift" and "u3" are not considered.
    const vpn: u9 = switch (level) {
        0 => @truncate(va >> 12),
        1 => @truncate(va >> 21),
        2 => @truncate(va >> 30),
        3 => @panic("Unsupported level for SV39!"),
    };
    return @intCast(vpn);
}
