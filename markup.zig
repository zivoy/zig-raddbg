const std = @import("std");
const builtin = @import("builtin");
const options = @import("options");

pub const std_views = @import("std_views.zig");

pub const enabled = options.enabled;

/// Equivalent of `raddbg_type_view(type, expr)`: tells the debugger how to visualize a type.
/// `T` can be a zig type or a string pattern
pub fn typeView(comptime T: anytype, comptime expr: []const u8) void {
    const name: []const u8 = if (@TypeOf(T) == type) @typeName(T) else T;
    embed("type_view: {type: ```" ++ name ++ "```, expr: ```" ++ expr ++ "```}");
}

/// Entry point by declaration: `entryPoint(@This(), "main")`
pub fn entryPoint(comptime ns: type, comptime decl: []const u8) void {
    if (!@hasDecl(ns, decl)) @compileError(@typeName(ns) ++ " has no declaration '" ++ decl ++ "'");
    entryPointName(@typeName(ns) ++ "." ++ decl);
}

/// Equivalent of `raddbg_entry_point(name)`: tells the debugger which symbol to treat as the program's entry point
pub fn entryPointName(comptime name: []const u8) void {
    embed("entry_point: \"" ++ name ++ "\"");
}

// ---

const section = ".raddbg";

fn embed(comptime str: []const u8) void {
    if (!enabled) return;

    switch (builtin.object_format) {
        .elf, .coff => {},
        else => return, // Mach-O needs "segment,section" - unsupported
    }

    // Global asm is the only way to set SHF_GNU_RETAIN ("R"), which keeps the section through `--gc-sections`
    const use_asm = builtin.object_format == .elf and builtin.zig_backend == .stage2_llvm;

    if (use_asm) {
        _ = AsmData(str);
    } else {
        const hash = std.hash.Wyhash.hash(0, str);
        const name = std.fmt.comptimePrint("raddbg_data__{x:0>16}", .{hash});
        @export(&VarData(str).bytes, .{ .name = name });
    }
}

fn VarData(comptime str: []const u8) type {
    return struct {
        // Leading NUL keeps linker padding from being glued onto the string
        const bytes: [str.len + 2]u8 linksection(section) = ("\x00" ++ str ++ "\x00").*;
    };
}

fn AsmData(comptime str: []const u8) type {
    return struct {
        comptime {
            @setEvalBranchQuota(str.len * 20 + 1000);

            var directives: []const u8 = "";
            for (str ++ "\x00") |byte| {
                directives = directives ++ ".byte 0x" ++ std.fmt.bytesToHex(&[_]u8{byte}, .lower) ++ "\n";
            }

            asm (std.fmt.comptimePrint(
                    \\.pushsection {s},"aR",%progbits
                    \\{s}
                    \\.popsection
                    \\
                , .{ section, directives }));
        }
    };
}

// ---

const testing = std.testing;

test "yes" {
    try testing.expect(true);
}
