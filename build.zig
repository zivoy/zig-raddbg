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

fn getDefualtProjectFile(path: ?std.Build.LazyPath, b: *std.Build, program_name: []const u8) std.Build.LazyPath {
    return path orelse b.path(b.fmt("{s}.raddbg_project", .{program_name}));
}

pub fn createProjectFile(raddbg_dep: *std.Build.Dependency, debugged_program: *std.Build.Step.Compile, project_file: std.Build.LazyPath) *std.Build.Step.Run {
    const owner = debugged_program.step.owner;
    const raddbg_project = raddbg_dep.builder;

    const exe = raddbg_project.addExecutable(.{
        .name = "raddbg_project",
        .root_module = raddbg_project.createModule(.{
            .root_source_file = raddbg_project.path("raddbg_project.zig"),
            .target = owner.graph.host,
            .optimize = .safe,
        }),
    });

    const markup = raddbg_project.addObjCopy(debugged_program.getEmittedBin(), .{ .format = .binary, .only_section = ".raddbg" });

    const run = owner.addRunArtifact(exe);
    run.addFileArg(markup.getOutput());
    run.addFileArg(project_file);
    run.has_side_effects = true;

    return run;
}

pub fn addProjectFile(raddbg_dep: *std.Build.Dependency, program: *std.Build.Step.Compile, path: ?std.Build.LazyPath) ?*std.Build.Step.Run {
    const target = program.rootModuleTarget();
    const owner = program.step.owner;
    if (target.ofmt != .elf) return null;

    const run = createProjectFile(raddbg_dep, program, getDefualtProjectFile(path, owner, program.name));
    owner.getInstallStep().dependOn(&run.step);
    return run;
}

pub fn addDebugProgram(raddbg_dep: *std.Build.Dependency, program: *std.Build.Step.Compile, project_file: ?std.Build.LazyPath) *std.Build.Step.Run {
    const target = program.rootModuleTarget();
    const owner = program.step.owner;

    const raddbg_prog = owner.findProgram(.{ .names = &.{"raddbg"} }) orelse {
        const fail_run = owner.addSystemCommand(&.{""});
        const fail = owner.addFail("raddbg not found");
        fail_run.step.dependOn(&fail.step);
        return fail_run;
    };
    const run_debugger = owner.addSystemCommand(&.{raddbg_prog});

    const project: ?std.Build.LazyPath = blk: {
        if (target.ofmt != .elf) break :blk null;
        const proj_path = getDefualtProjectFile(project_file, owner, program.name);
        const build_proj = createProjectFile(raddbg_dep, program, proj_path);
        run_debugger.step.dependOn(&build_proj.step);
        break :blk proj_path;
    } orelse project_file;

    if (project != null) run_debugger.addFileArg2(project.?, .{ .prefix = "--project:" });

    run_debugger.addFileArg2(program.getEmittedBin(), .{});

    return run_debugger;
}
