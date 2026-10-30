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

fn getDefualtProjectFile(path: ?std.Build.LazyPath, base_path: std.Build.LazyPath, b: *std.Build, program_name: []const u8) std.Build.LazyPath {
    return path orelse base_path.path(b, b.fmt("{s}.raddbg_project", .{program_name}));
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
    run.addFileArg(owner.path("."));
    run.addFileArg(debugged_program.getEmittedBin());
    run.has_side_effects = true;

    return run;
}

pub fn addProjectFile(raddbg_dep: *std.Build.Dependency, program: *std.Build.Step.Compile, path: ?std.Build.LazyPath) ?*std.Build.Step.Run {
    const target = program.rootModuleTarget();
    const owner = program.step.owner;
    if (target.ofmt != .elf) return null;

    const run = createProjectFile(raddbg_dep, program, getDefualtProjectFile(path, owner.path("."), owner, program.name));
    owner.getInstallStep().dependOn(&run.step);
    return run;
}

// options from readme
pub const RaddbgOptions = struct {
    /// Run all active targets after the debugger initially initially starts.
    auto_run: bool = false,
    /// Use to specify the location of a user file which should be used. User files are used by default to store user-related settings, including window and panel setups, path mapping, and visual settings.
    /// If this file does not exist, it will be created as necessary. This file will be autosaved as user-related changes are made.
    user: ?std.Build.LazyPath = null,
    /// Use to specify the location of a project file which should be used. Project files are used by default to store project-related settings.
    /// If this file does not exist, it will be created as necessary. This file will be autosaved as project-related changes are made.
    project: ?std.Build.LazyPath = null,
    /// Close the debugger automatically after all processes exit, if they all exited successfully (with code 0), and ran with no interruptions.
    quit_after_success: bool = false,
    // ipc: bool = false,
};

pub fn addDebugProgram(raddbg_dep: *std.Build.Dependency, program: *std.Build.Step.Compile, options: RaddbgOptions) *std.Build.Step.Run {
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
        const proj_path = getDefualtProjectFile(options.project, program.getEmittedBinDirectory(), owner, program.name);
        const build_proj = createProjectFile(raddbg_dep, program, proj_path);
        run_debugger.step.dependOn(&build_proj.step);
        break :blk proj_path;
    } orelse options.project;

    if (project != null) run_debugger.addFileArg2(project.?, .{ .prefix = "--project:" });
    if (options.user != null) run_debugger.addFileArg2(options.user.?, .{ .prefix = "--user:" });
    if (options.auto_run) run_debugger.addArg("--auto_run");
    if (options.quit_after_success) run_debugger.addArg("--quit_after_success");

    run_debugger.addFileArg2(program.getEmittedBin(), .{});

    return run_debugger;
}
