const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raddbg_dep = b.dependency("raddbg", .{
        .target = target,
        .optimize = optimize,
        .enabled = true,
    });

    const test_exe = b.addExecutable(.{
        .name = "test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "raddbg", .module = raddbg_dep.module("raddbg") },
            },
        }),
        .use_llvm = true, // raddbg crashes with the zig backend https://github.com/EpicGames/raddebugger/issues/1006
    });
    b.installArtifact(test_exe);

    const types_exe = b.addExecutable(.{
        .name = "types_test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("types_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "raddbg", .module = raddbg_dep.module("raddbg") },
            },
        }),
        .use_llvm = true,
    });
    b.installArtifact(types_exe);
}
