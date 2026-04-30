const std = @import("std");

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
    kernel.setLinkerScript(b.path("os/linker.ld"));
    b.installArtifact(kernel);

    const qemu_cmd = b.addSystemCommand(&.{
        "qemu-system-riscv64",
        "-machine", "virt",
        "-nographic",
        "-bios", "bootloader/opensbi.bin",
        "-kernel",
    });
    qemu_cmd.addArtifactArg(kernel);
    qemu_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the kernel in QEMU");
    run_step.dependOn(&qemu_cmd.step);
}
