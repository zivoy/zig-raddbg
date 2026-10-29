const std = @import("std");
const builtin = @import("builtin");
const options = @import("options");

pub const std_views = @import("std_views.zig");

// match c functionality of allowing to disable raddbg from within the program
const root = @import("root");
const markup_enabled = !(@hasDecl(root, "raddbg_markup_stubs") and root.raddbg_markup_stubs);

pub const enabled = markup_enabled and options.enabled;

/// Equivalent of `raddbg_type_view(type, expr)`: tells the debugger how to visualize a type.
/// `T` can be a zig type or a string pattern
pub fn typeView(comptime T: anytype, comptime expr: []const u8) void {
    const name: []const u8 = if (@TypeOf(T) == type) @typeName(T) else T;
    embed("type_view: {type: ```" ++ name ++ "```, expr: ```" ++ expr ++ "```}");
}

/// Equivalent of `raddbg_entry_point(name)`: tells the debugger which symbol to treat as the program's entry point
pub fn entryPoint(comptime name: []const u8) void {
    embed("entry_point: \"" ++ name ++ "\"");
}

// ---

/// Equivalent of `raddbg_is_attached()`: true once the debugger has attached
pub fn isAttached() bool {
    if (!enabled) return false;
    // volatile: the debugger writes the byte from outside, so the read must not be folded to 0
    return @as(*const volatile u8, &Marker.byte[0]).* != 0;
}

// ---

const section = ".raddbg";
const is_attached_section = ".rdbgia";

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

// --- is attached ---
// The debugger finds the `.rdbgia` section in the loaded image and writes a non-zero value into it when it attaches.

const Marker = struct {
    var byte: [1]u8 linksection(is_attached_section) = .{0};
};

comptime {
    if (enabled) {
        @export(&Marker.byte, .{ .name = "raddbg_is_attached_byte_marker" });
    }
}

// ---

const testing = std.testing;

test "yes" {
    try testing.expect(true);
}
