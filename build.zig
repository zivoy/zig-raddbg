const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const enabled = b.option(bool, "enabled", "when true raddb markup is written to the executable (default true)") orelse true;

    const options = b.addOptions();
    options.addOption(bool, "enabled", enabled);

    const mod = b.addModule("raddbg", .{
        .root_source_file = b.path("markup.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "options", .module = options.createModule() },
        },
    });

    // ---

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
