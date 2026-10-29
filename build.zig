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
    const mod_tests_llvm = b.addTest(.{
        .root_module = mod,
        .use_llvm = true,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);
    const run_mod_tests_llvm = b.addRunArtifact(mod_tests_llvm);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_mod_tests_llvm.step);
}

pub fn makeRaddbgProject(b: *std.Build, debuggedProgram: *std.Build.Step.Compile, projectFile: std.Build.LazyPath) *std.Build.Step.Run {
    const exe = b.addExecutable(.{
        .name = "raddbg_project",
        .root_module = b.createModule(.{
            .root_source_file = b.path("raddbg_project.zig"),
            .target = b.graph.host,
            .optimize = .safe,
        }),
    });

    const markup = b.addObjCopy(debuggedProgram.getEmittedBin(), .{ .format = .binary, .only_section = ".raddbg" });

    const run = b.addRunArtifact(exe);
    run.addFileArg(markup.getOutput());
    run.addFileArg(projectFile);
    run.has_side_effects = true;

    return run;
}

pub fn debugProgram(b: *std.Build, program: *std.Build.Step.Compile) *std.Build.Step.Run {
    var project: ?std.Build.LazyPath = null;
    if (b.graph.host.result.os.tag == .linux) {
        project = program.getEmittedBinDirectory().path(b, b.fmt("{s}.raddbg_project", .{program.name}));
        _ = makeRaddbgProject(b, program, project.?);
    }

    const run_debugger = b.addSystemCommand(&.{"raddbg"});
    if (project != null) run_debugger.addFileArg2(project.?, .{ .prefix = "--project:" });
    run_debugger.addFileArg2(program.getEmittedBin(), .{});

    return run_debugger;
}
