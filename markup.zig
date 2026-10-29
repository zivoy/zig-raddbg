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
    if (@as(*const volatile u8, &Marker.byte[0]).* != 0) return true;
    // linux fallback, check TracerPid
    if (builtin.os.tag == .linux) return tracedByDebugger();
    return false;
}

/// Equivalent of `raddbg_thread_id()`: the id the debugger knows the calling thread by
pub fn threadId() std.Thread.Id {
    @panic("TODO: raddbg threadId");
}

/// Equivalent of `raddbg_thread_name(fmt, ...)`: names the calling thread in the debugger
pub fn threadName(comptime fmt: []const u8, args: anytype) void {
    _ = fmt; // autofix
    _ = args; // autofix
    @panic("TODO: raddbg threadName");
}

/// Equivalent of `raddbg_thread_id_name(id, fmt, ...)`: names the thread with the given id in the debugger
pub fn threadIdName(id: std.Thread.Id, comptime fmt: []const u8, args: anytype) void {
    _ = id; // autofix
    _ = fmt; // autofix
    _ = args; // autofix
    @panic("TODO: raddbg threadIdName");
}

/// Equivalent of `raddbg_thread_color_u32(u32)`: colours the calling thread in the debugger, `0xRRGGBBAA`
pub fn threadColorU32(rgba: u32) void {
    _ = rgba; // autofix
    @panic("TODO: raddbg threadColorU32");
}

/// Equivalent of `raddbg_thread_color_rgba(r, g, b, a)`: colours the calling thread in the debugger, each channel is 0 to 1
pub fn threadColorRgba(r: f32, g: f32, b: f32, a: f32) void {
    _ = r; // autofix
    _ = g; // autofix
    _ = b; // autofix
    _ = a; // autofix
    @panic("TODO: raddbg threadColorRgba");
}

/// Equivalent of `raddbg_thread_id_color_u32(id, u32)`: colours the thread with the given id in the debugger, `0xRRGGBBAA`
pub fn threadIdColorU32(id: std.Thread.Id, rgba: u32) void {
    _ = id; // autofix
    _ = rgba; // autofix
    @panic("TODO: raddbg threadIdColorU32");
}

/// Equivalent of `raddbg_thread_id_color_rgba(id, r, g, b, a)`: colours the thread with the given id in the debugger, each channel is 0 to 1
pub fn threadIdColorRgba(id: std.Thread.Id, r: f32, g: f32, b: f32, a: f32) void {
    _ = id; // autofix
    _ = r; // autofix
    _ = g; // autofix
    _ = b; // autofix
    _ = a; // autofix
    @panic("TODO: raddbg threadIdColorRgba");
}

/// Equivalent of `raddbg_break()`: stops in the debugger at this point
pub inline fn breakpoint() void {
    if (!enabled) return;
    @breakpoint();
}

/// Equivalent of `raddbg_break_if(expr)`: stops in the debugger at this point if `condition` is true
pub inline fn breakpointIf(condition: bool) void {
    if (condition) breakpoint();
}

/// Equivalent of `raddbg_watch(fmt, ...)`: adds an expression to the debug
/// Does nothing in the C header either (marked TODO there).
pub fn watch(comptime fmt: []const u8, args: anytype) void {
    _ = fmt; // autofix
    _ = args; // autofix
    @panic("TODO: raddbg watch");
}

/// Equivalent of `raddbg_pin(expr, ...)`: the debugger shows `expr` next to this line of source.
pub fn pin(comptime expr: []const u8, args: anytype) void {
    _ = expr; // autofix
    _ = args; // autofix
    @panic("TODO: raddbg pin");
}

/// Equivalent of `raddbg_log(fmt, ...)`: writes to the debugger's log
pub fn log(comptime fmt: []const u8, args: anytype) void {
    _ = fmt; // autofix
    _ = args; // autofix
    @panic("TODO: raddbg log");
}

/// Which accesses of an address range stop the debugger. Used by `addBreakpoint` and `removeBreakpoint`.
pub const Access = packed struct {
    read: bool = false,
    write: bool = false,
    execute: bool = false,
};

/// Equivalent of `raddbg_add_breakpoint(ptr, size, r, w, x)`: breaks on the given accesses of `size` bytes at `ptr`
pub fn addBreakpoint(ptr: *const anyopaque, size: usize, access: Access) void {
    _ = .{ ptr, size, access };
    @panic("TODO: raddbg addBreakpoint");
}

/// Equivalent of `raddbg_remove_breakpoint(ptr, size, r, w, x)`: removes a breakpoint made with `addBreakpoint`
pub fn removeBreakpoint(ptr: *const anyopaque, size: usize, access: Access) void {
    _ = .{ ptr, size, access };
    @panic("TODO: raddbg removeBreakpoint");
}

/// Equivalent of `raddbg_annotate_vaddr_range(ptr, size, fmt, ...)`: labels `size` bytes at `ptr` in the debugger
pub fn annotateVaddrRange(ptr: *const anyopaque, size: usize, comptime fmt: []const u8, args: anytype) void {
    _ = .{ ptr, size, fmt, args };
    @panic("TODO: raddbg annotateVaddrRange");
}

/// Equivalent of `raddbg_load_module(ptr, size, name, dbg_path)`: tells the debugger a module is loaded at `ptr`, with its debug info at `dbg_path`
pub fn loadModule(ptr: *const anyopaque, size: usize, name: [*:0]const u8, dbg_path: [*:0]const u8) void {
    _ = .{ ptr, size, name, dbg_path };
    @panic("TODO: raddbg loadModule");
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

fn tracedByDebugger() bool {
    std.debug.assert(builtin.os.tag == .linux);
    // debugging aid, so the global single-threaded Io is used instead of asking the caller for one
    const io = std.Io.Threaded.global_single_threaded.io();

    var buffer: [512]u8 = undefined;
    const status = std.Io.Dir.cwd().readFile(io, "/proc/self/status", &buffer) catch return false;

    const key = "TracerPid:";
    const start = std.mem.indexOf(u8, status, key) orelse return false;
    const value = std.mem.trim(u8, status[start + key.len ..], " \t");
    return value.len > 0 and value[0] != '0';
}

// ---

const testing = std.testing;

test "yes" {
    try testing.expect(true);
}
