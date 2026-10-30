# Zig Rad debugger markup

Zig port of [raddbg_markup.h](https://github.com/EpicGames/raddebugger/blob/master/src/lib_raddbg_markup/raddbg_markup.h) for the [RAD Debugger](https://github.com/EpicGames/raddebugger).
Allowing you to tell the debugger how to display certain types.

Also, there is a build time helpers `addProjectFile` and `addDebugProgram` for extracting the markup from inside of an elf binary to the raddbg project format, and for running the debugger after the program is built.
The first one is needed because on linux raddbg can't parse the directives from the `.raddbg` section of the binary.

## Zig Version

0.17.0

## Example

(check the test dir for working example)

Add it to your project using

```bash
zig fetch --save git+https://github.com/zivoy/zig-raddbg
```

In your build.zig file

```zig
const raddbg_dep = b.dependency("raddbg", .{
    .target = target,
    .optimize = optimize,
    // set to false to disable adding markup and disabling breakpoints,
    // you might want to tie this to optimize if you do not want to ship debug info in prod (optimize == .debug).
    .enabled = true,
});

// ---

// raddbg on linux currently crashes with zig's self-hosted backend - https://github.com/EpicGames/raddebugger/issues/1006
exe.use_llvm = true;
exe.root_module.addImport("raddbg", raddbg_dep.module("raddbg"));

// --- optional ---

// this allows you to use zig build debug to build your program and immediately open it in the debugger,
// you can use `--auto_run` to also start it. See the RAD debugger `raddbg_readme.md` for more info.
const debug_step = b.step("debug", "Run program in debugger");
const debug_run = @import("raddbg").addDebugProgram(raddbg_dep, exe, null));
// debug_run.addArg("--auto_run");
debug_step.dependOn(&debug_run.step);
```

Then you can use it in your project

```zig
const raddbg = @import("raddbg");

const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    comptime {
        // this block will only be emitted if Vec3 is actually used in your program
        raddbg.typeView(Vec3, "rows($, x, y, z)");
    }
};

comptime {
    // you will want to use this helper to register views for the standard lib and zig types like []T
    raddbg.std_views.registerDefaults();
}

// like in the c header version, you can set this to true to disable raddbg features from within the program.
pub const raddbg_markup_stubs = false;

// in a function
@breakpoint();       // works
raddbg.breakpoint(); // also works, and is disabled when raddbg is disabled

// using the helpers
if(raddbg.isAttached()) std.log.info("debugger is attached", .{});
```

## Contributing

Just make a pr

## License

This project is licensed under the [MIT License](./LICENSE).

## TODO

- Finish the implementation, there are functions for things like setting thread name etc.
- Look into making helpers for composing views, maybe comptime verification
- verify this works on windows
- some odd or large types do not display correctly (f16, f80, i128)
- there is an issue where array is not getting the type when with an offset, this is an issue for MultiArrayList and it's helper `raddbg.std_views.multiArrayListOf` which right now is just showing the memory instead of using `array`
