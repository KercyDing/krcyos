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

    const board = b.option(Board, "board", "Target board platform") orelse .qemu_virt;

    const log = b.option(Log, "log", "The lowest log level") orelse .info;

    const tests = b.option(bool, "tests", "Enable kernel tests") orelse true;
    const options = b.addOptions();
    options.addOption(Board, "board", board);
    options.addOption(Log, "log", log);
    options.addOption(bool, "tests", tests);

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
    const root_module = kernel.root_module;

    // Core module graph.
    const config_mod = options.createModule();
    const constants_mod = b.createModule(.{
        .root_source_file = b.path("os/constants.zig"),
    });
    const arch_mod = b.createModule(.{
        .root_source_file = b.path("os/arch/root.zig"),
    });
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("os/lib/root.zig"),
    });
    const ipc_mod = b.createModule(.{
        .root_source_file = b.path("os/ipc/root.zig"),
    });
    const mm_mod = b.createModule(.{
        .root_source_file = b.path("os/mm/root.zig"),
    });
    const task_mod = b.createModule(.{
        .root_source_file = b.path("os/task/root.zig"),
    });

    // Root module imports.
    root_module.addImport("config", config_mod);
    root_module.addImport("constants", constants_mod);

    root_module.addImport("arch", arch_mod);

    root_module.addImport("lib", lib_mod);
    root_module.addImport("ipc", ipc_mod);

    root_module.addImport("mm", mm_mod);
    root_module.addImport("task", task_mod);

    root_module.addAssemblyFile(b.path("os/arch/switch.S"));

    // Internal module dependencies.
    arch_mod.addImport("constants", constants_mod);
    arch_mod.addImport("config", config_mod);
    arch_mod.addImport("lib", lib_mod);
    arch_mod.addImport("task", task_mod);

    lib_mod.addImport("constants", constants_mod);
    lib_mod.addImport("config", config_mod);

    mm_mod.addImport("constants", constants_mod);
    mm_mod.addImport("lib", lib_mod);

    task_mod.addImport("arch", arch_mod);
    task_mod.addImport("constants", constants_mod);
    task_mod.addImport("lib", lib_mod);

    kernel.setLinkerScript(b.path("os/linker.ld"));
    b.installArtifact(kernel);

    const run_step = b.step("run", "Run the kernel");

    switch (board) {
        .qemu_virt => {
            const qemu_cmd = b.addSystemCommand(&.{
                "qemu-system-riscv64",
                "-machine",
                "virt",
                "-nographic",
                "-bios",
                sbi_path,
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

    const test_step = b.step("test", "Run pure unit tests");
    const host_target = b.resolveTargetQuery(.{});

    const unit_tests_mod = b.createModule(.{
        .root_source_file = b.path("os/unit_tests.zig"),
        .target = host_target,
        .optimize = optimize,
    });
    unit_tests_mod.addImport("constants", constants_mod);

    const unit_tests = b.addTest(.{
        .root_module = unit_tests_mod,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    test_step.dependOn(&run_unit_tests.step);
}
