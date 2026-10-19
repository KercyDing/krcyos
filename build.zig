const std = @import("std");
const builtin = @import("builtin");

const Board = enum {
    qemu_virt,
    real_board,
};

const Mode = enum {
    super,
    user,
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

    const mode = b.option(Mode, "mode", "Target mode") orelse .super;

    const options = b.addOptions();
    options.addOption(Board, "board", board);
    options.addOption(Log, "log", log);
    options.addOption(Mode, "mode", mode);

    const sbi_path = if (log == .debug)
        "bootloader/opensbi_debug.bin"
    else
        "bootloader/opensbi.bin";

    // ========== Modules ==========
    const config_mod = options.createModule();

    const constants_mod = b.createModule(.{
        .root_source_file = b.path("os/constants.zig"),
    });

    const abi_mod = b.createModule(.{
        .root_source_file = b.path("os/abi/root.zig"),
    });

    // Require Import
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("os/lib/root.zig"),
        .imports = &.{
            .{ .name = "config", .module = config_mod },
            .{ .name = "constants", .module = constants_mod },
        },
    });

    const arch_mod = b.createModule(.{
        .root_source_file = b.path("os/arch/root.zig"),
        .imports = &.{
            .{ .name = "config", .module = config_mod },
            .{ .name = "constants", .module = constants_mod },
        },
    });

    const mm_mod = b.createModule(.{
        .root_source_file = b.path("os/mm/root.zig"),
        .imports = &.{
            .{ .name = "constants", .module = constants_mod },
            .{ .name = "abi", .module = abi_mod },
            .{ .name = "lib", .module = lib_mod },
        },
    });

    const task_mod = b.createModule(.{
        .root_source_file = b.path("os/task/root.zig"),
        .imports = &.{
            .{ .name = "arch", .module = arch_mod },
            .{ .name = "constants", .module = constants_mod },
            .{ .name = "lib", .module = lib_mod },
        },
    });

    const user_mod = b.createModule(.{
        .root_source_file = b.path("os/user/root.zig"),
        .imports = &.{
            .{ .name = "constants", .module = constants_mod },
            .{ .name = "abi", .module = abi_mod },
        },
    });

    const syscall_mod = b.createModule(.{
        .root_source_file = b.path("os/syscall/root.zig"),
        .imports = &.{
            .{ .name = "abi", .module = abi_mod },
            .{ .name = "lib", .module = lib_mod },
            .{ .name = "arch", .module = arch_mod },
            .{ .name = "user", .module = user_mod },
        },
    });

    const trap_mod = b.createModule(.{
        .root_source_file = b.path("os/trap/root.zig"),
        .imports = &.{
            .{ .name = "constants", .module = constants_mod },
            .{ .name = "abi", .module = abi_mod },
            .{ .name = "lib", .module = lib_mod },
            .{ .name = "arch", .module = arch_mod },
            .{ .name = "task", .module = task_mod },
            .{ .name = "syscall", .module = syscall_mod },
        },
    });

    // Kernel Module
    const kernel_mod = b.createModule(.{
        .root_source_file = b.path("os/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
        .code_model = .medany,
        .imports = &.{
            .{ .name = "config", .module = config_mod },
            .{ .name = "constants", .module = constants_mod },
            .{ .name = "abi", .module = abi_mod },
            .{ .name = "lib", .module = lib_mod },
            .{ .name = "arch", .module = arch_mod },
            .{ .name = "mm", .module = mm_mod },
            .{ .name = "task", .module = task_mod },
            .{ .name = "user", .module = user_mod },
            .{ .name = "trap", .module = trap_mod },
        },
    });
    kernel_mod.addAssemblyFile(b.path("os/arch/switch.S"));

    const kernel_exe = b.addExecutable(.{
        .name = "krcyos",
        .root_module = kernel_mod,
    });

    kernel_exe.setLinkerScript(b.path("os/linker.ld"));
    b.installArtifact(kernel_exe);

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
            qemu_cmd.addArtifactArg(kernel_exe);
            qemu_cmd.step.dependOn(b.getInstallStep());
            run_step.dependOn(&qemu_cmd.step);
        },
        .real_board => {
            std.log.info("Build finished. Please flash to your board.", .{});
        },
    }

    const test_step = b.step("test", "Run pure unit tests");
    const host_target = b.resolveTargetQuery(.{});

    const unit_tests_mod = b.createModule(.{
        .root_source_file = b.path("os/unit_tests.zig"),
        .target = host_target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "lib", .module = lib_mod },
        },
    });

    const unit_tests = b.addTest(.{
        .root_module = unit_tests_mod,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    test_step.dependOn(&run_unit_tests.step);
}

comptime {
    const minimum = std.SemanticVersion.parse("0.17.0") catch unreachable;

    if (builtin.zig_version.order(minimum) == .lt) {
        @compileError(std.fmt.comptimePrint(
            \\Your version of Zig is too old.
            \\Minimum required version: 0.17.0
        , .{}));
    }
}
