const std = @import("std");

const Board = enum {
    qemu_virt,
    real_board,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .riscv64,
            .os_tag = .freestanding,
            .abi = .none,
        },
    });
    const optimize = b.standardOptimizeOption(.{});
    const strip = b.option(bool, "strip", "Strip debug info") orelse false;
    const board = b.option(Board, "board", "Target board platform") orelse .qemu_virt;

    const options = b.addOptions();
    options.addOption(Board, "board", board);

    const kernel = b.addExecutable(.{
        .name = "krcyos",
        .root_module = b.createModule(.{
            .root_source_file = b.path("os/main.zig"),
                .target = target,
                .optimize = optimize,
                .strip = strip,
                .code_model = .medany,
        }),
    });
    kernel.root_module.addImport("config", options.createModule());
    kernel.setLinkerScript(b.path("os/linker.ld"));
    b.installArtifact(kernel);

    const run_step = b.step("run", "Run the kernel");

    if (board == .qemu_virt) {
        const qemu_cmd = b.addSystemCommand(&.{
            "qemu-system-riscv64",
            "-machine", "virt",
            "-nographic",
            "-bios", "bootloader/opensbi.bin",
            "-kernel",
        });
        qemu_cmd.addArtifactArg(kernel);
        qemu_cmd.step.dependOn(b.getInstallStep());
        run_step.dependOn(&qemu_cmd.step);
    } else {
        const print_cmd = b.addSystemCommand(&.{ "echo", "Build finished. Please flash to board." });
        run_step.dependOn(&print_cmd.step);
    }
}
