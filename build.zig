const std = @import("std");

const Board = enum {
    qemu_virt,
    real_board,
};

const Log = enum {
    debug,
    info,
    warn,
    @"error",
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

    const board = b.option(Board, "board", "Target board platform (required)") orelse {
        std.log.err("You MUST specify a target board.", .{});
        std.log.info("Use 'zig build run -Dboard=qemu_virt'\n      or  'zig build run -Dboard=real_board'", .{});
        std.process.exit(1);
    };

    const log = b.option(Log, "log", "The lowest log level") orelse .debug;

    const options = b.addOptions();
    options.addOption(Board, "board", board);
    options.addOption(Log, "log", log);

    const sbi_path = if (log == .debug)
        "bootloader/opensbi_debug.bin"
    else
        "bootloader/opensbi.bin";

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

    switch (board) {
        .qemu_virt => {
            const qemu_cmd = b.addSystemCommand(&.{
                "qemu-system-riscv64",
                "-machine", "virt",
                "-nographic",
                "-bios", sbi_path,
                "-kernel",
            });
            qemu_cmd.addArtifactArg(kernel);
            qemu_cmd.step.dependOn(b.getInstallStep());
            run_step.dependOn(&qemu_cmd.step);
        },
        .real_board => {
            const print_cmd = b.addSystemCommand(&.{ "echo", "Build finished. Please flash to board." });
            run_step.dependOn(&print_cmd.step);
        },
    }
}
