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

    _ = b.addModule("raddbg_project", .{});

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

pub fn makeRaddbgProject(b: *std.Build, raddbg_project: *std.Build, debugged_program: *std.Build.Step.Compile, project_file: std.Build.LazyPath) *std.Build.Step.Run {
    const exe = raddbg_project.addExecutable(.{
        .name = "raddbg_project",
        .root_module = raddbg_project.createModule(.{
            .root_source_file = raddbg_project.path("raddbg_project.zig"),
            .target = b.graph.host,
            .optimize = .safe,
        }),
    });

    const markup = raddbg_project.addObjCopy(debugged_program.getEmittedBin(), .{ .format = .binary, .only_section = ".raddbg" });

    const run = b.addRunArtifact(exe);
    run.addFileArg(markup.getOutput());
    run.addFileArg(project_file);
    run.has_side_effects = true;

    return run;
}

pub fn debugProgram(b: *std.Build, raddbg_dep: *std.Build.Dependency, program: *std.Build.Step.Compile, project_file: ?std.Build.LazyPath) *std.Build.Step.Run {
    const run_debugger = b.addSystemCommand(&.{"raddbg"});

    const target = if (program.root_module.resolved_target != null) program.root_module.resolved_target.? else b.graph.host;
    if (target.result.os.tag == .linux) {
        var project = program.getEmittedBinDirectory().path(b, b.fmt("{s}.raddbg_project", .{program.name}));
        if (project_file) |proj| project = proj;
        const build_proj = makeRaddbgProject(b, raddbg_dep.builder, program, project);
        run_debugger.step.dependOn(&build_proj.step);

        run_debugger.addFileArg2(project, .{ .prefix = "--project:" });
    }

    run_debugger.addFileArg2(program.getEmittedBin(), .{});

    return run_debugger;
}
