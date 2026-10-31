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
    embed(typeViewText(T, expr));
}

fn typeViewText(comptime T: anytype, comptime expr: []const u8) []const u8 {
    const name: []const u8 = if (@TypeOf(T) == type) @typeName(T) else T;
    return "type_view: {type: ```" ++ name ++ "```, expr: ```" ++ expr ++ "```}";
}

/// Equivalent of `raddbg_entry_point(name)`: tells the debugger which symbol to treat as the program's entry point
pub fn entryPoint(comptime name: []const u8) void {
    embed(entryPointText(name));
}

fn entryPointText(comptime name: []const u8) []const u8 {
    return "entry_point: \"" ++ name ++ "\"";
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
    return std.Thread.getCurrentId();
}

/// Equivalent of `raddbg_thread_name(fmt, ...)`: names the calling thread in the debugger
pub fn threadName(comptime fmt: []const u8, args: anytype) void {
    threadIdName(threadId(), fmt, args);
}

/// Equivalent of `raddbg_thread_id_name(id, fmt, ...)`: names the thread with the given id in the debugger
pub fn threadIdName(id: std.Thread.Id, comptime fmt: []const u8, args: anytype) void {
    if (!enabled) return;

    var buf: [512]u8 = undefined;
    const name = bufPrintTruncateZ(&buf, fmt, args);

    switch (builtin.os.tag) {
        .linux => {
            var path_buffer: [64]u8 = undefined;
            const path = std.fmt.bufPrint(&path_buffer, "/proc/self/task/{d}/comm", .{id}) catch return;
            const io = std.Io.Threaded.global_single_threaded.io();
            // kernel limit is 15 bytes + NUL
            std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = name[0..@min(name.len, 15)] }) catch {};
        },
        .windows => if (win32_enabled) {
            // windows 10 style, only works on the calling thread
            const set_description = if (id == threadId()) win32.setThreadDescription() else null;
            if (set_description) |setDescription| {
                // 512*u16 == 1024*u8
                var name16: [512:0]u16 = undefined;

                if (std.unicode.utf8ToUtf16Le(&name16, name)) |len| {
                    name16[len] = 0;
                    _ = setDescription(win32.GetCurrentThread(), name16[0..len :0]);
                } else |_| {}
            }
            // every windows debugger understands this code, but nothing catches it without one
            if (win32.IsDebuggerPresent().toBool()) win32.raise(.thread_name, &.{ 0x1000, @intFromPtr(name.ptr), id });
        },
        else => {},
    }
}

/// Equivalent of `raddbg_thread_color_u32(u32)`: colours the calling thread in the debugger, `0xRRGGBBAA`
pub fn threadColorU32(rgba: u32) void {
    threadIdColorU32(threadId(), rgba);
}

/// Equivalent of `raddbg_thread_color_rgba(r, g, b, a)`: colours the calling thread in the debugger, each channel is 0 to 1
pub fn threadColorRgba(r: f32, g: f32, b: f32, a: f32) void {
    threadIdColorRgba(threadId(), r, g, b, a);
}

/// Equivalent of `raddbg_thread_id_color_u32(id, u32)`: colours the thread with the given id in the debugger, `0xRRGGBBAA`
pub fn threadIdColorU32(id: std.Thread.Id, rgba: u32) void {
    if (!enabled) return;
    // if (builtin.os.tag != .windows) return; // not available on linux
    if (!notifiable()) return;
    win32.raise(.thread_color, &.{ id, rgba });
}

/// Equivalent of `raddbg_thread_id_color_rgba(id, r, g, b, a)`: colours the thread with the given id in the debugger, each channel is 0 to 1
pub fn threadIdColorRgba(id: std.Thread.Id, r: f32, g: f32, b: f32, a: f32) void {
    threadIdColorU32(id, Rgba.pack(r, g, b, a));
}

/// Equivalent of `raddbg_break()`: stops in the debugger at this point
pub inline fn breakpoint() void {
    if (!enabled) return;
    @breakpoint();
}

/// Equivalent of `raddbg_break_if(expr)`: stops in the debugger at this point if `condition` is true
pub inline fn breakpointIf(condition: bool) void {
    if (enabled and condition) @breakpoint();
}

/// Equivalent of `raddbg_watch(fmt, ...)`: adds an expression to the debugger's watch window.
pub fn watch(comptime fmt: []const u8, args: anytype) void {
    // Does nothing in the C header (marked TODO)
    _ = fmt;
    _ = args;
}

/// Equivalent of `raddbg_pin(expr, ...)`: the debugger shows `expr` next to this line of source.
pub fn pin(comptime expr: []const u8, args: anytype) void {
    // Does nothing in the C header (marked TODO)
    _ = expr;
    _ = args;
}

/// Equivalent of `raddbg_log(fmt, ...)`: writes to the debugger's log
pub fn log(comptime fmt: []const u8, args: anytype) void {
    if (!enabled) return;
    if (builtin.os.tag != .windows) return std.log.scoped(.raddbg).info(fmt, args);

    var buf: [4096]u8 = undefined;
    const msg = bufPrintTruncateZ(&buf, fmt, args);
    win32.OutputDebugStringA(msg.ptr);
}

/// Which accesses of an address range stop the debugger.
/// Used by `addBreakpoint` and `removeBreakpoint`.
pub const Access = packed struct {
    read: bool = false,
    write: bool = false,
    execute: bool = false,
};

/// Equivalent of `raddbg_add_breakpoint(ptr, size, r, w, x)`: breaks on the given accesses of `size` bytes at `ptr`
pub fn addBreakpoint(ptr: *const anyopaque, size: usize, access: Access) void {
    setBreakpoint(ptr, size, access, true);
}

/// Equivalent of `raddbg_remove_breakpoint(ptr, size, r, w, x)`: removes a breakpoint made with `addBreakpoint`
pub fn removeBreakpoint(ptr: *const anyopaque, size: usize, access: Access) void {
    setBreakpoint(ptr, size, access, false);
}

fn setBreakpoint(ptr: *const anyopaque, size: usize, access: Access, add: bool) void {
    if (!enabled) return;
    // if (builtin.os.tag != .windows) return; // not available on linux
    if (!notifiable()) return;
    win32.raise(.breakpoint, &.{
        @intFromPtr(ptr),
        size,
        @intFromBool(access.read),
        @intFromBool(access.write),
        @intFromBool(access.execute),
        @intFromBool(add),
    });
}

/// Equivalent of `raddbg_annotate_vaddr_range(ptr, size, fmt, ...)`: labels `size` bytes at `ptr` in the debugger
pub fn annotateVaddrRange(ptr: *const anyopaque, size: usize, comptime fmt: []const u8, args: anytype) void {
    if (builtin.os.tag != .windows) return; // not available on linux
    _ = ptr; // autofix
    _ = size; // autofix
    _ = fmt; // autofix
    _ = args; // autofix
    @panic("TODO: raddbg annotateVaddrRange");
}

/// Equivalent of `raddbg_load_module(ptr, size, name, dbg_path)`: tells the debugger a module is loaded at `ptr`, with its debug info at `dbg_path`
pub fn loadModule(ptr: *const anyopaque, size: usize, name: [*:0]const u8, dbg_path: [*:0]const u8) void {
    if (!enabled) return;
    // if (builtin.os.tag != .windows) return; // not available on linux
    if (!notifiable()) return;
    win32.raise(.load_module, &.{ @intFromPtr(ptr), size, @intFromPtr(name), @intFromPtr(dbg_path) });
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
    return hasTracer(status);
}

/// `status` is the contents of `/proc/PID/status`
fn hasTracer(status: []const u8) bool {
    const key = "TracerPid:";
    const start = std.mem.indexOf(u8, status, key) orelse return false;
    const value = std.mem.trim(u8, status[start + key.len ..], " \t");
    return value.len > 0 and value[0] != '0';
}

fn bufPrintTruncateZ(buffer: []u8, comptime fmt: []const u8, args: anytype) [:0]const u8 {
    return std.mem.printSentinel(buffer, fmt, args, 0) catch blk: {
        buffer[buffer.len - 1] = 0;
        break :blk buffer[0 .. buffer.len - 1 :0];
    };
}

/// `0xRRGGBBAA`
const Rgba = packed struct(u32) {
    a: u8,
    b: u8,
    g: u8,
    r: u8,

    pub fn channel(value: f32) u8 {
        return @intFromFloat(std.math.clamp(value, 0, 1) * 255);
    }

    pub fn pack(r: f32, g: f32, b: f32, a: f32) u32 {
        const rgba: Rgba = .{ .r = channel(r), .g = channel(g), .b = channel(b), .a = channel(a) };
        return @bitCast(rgba);
    }
};

// ---

const win32_enabled = builtin.os.tag == .windows and @sizeOf(usize) == @sizeOf(u64) and enabled;

/// debug codes only for a present raddbg
fn notifiable() bool {
    return win32_enabled and isAttached();
}

const win32 = if (win32_enabled) struct {
    const ExceptionCode = enum(DWORD) {
        thread_name = 0x406D1388,
        thread_color = 0x00524144,
        breakpoint = 0x00524145,
        annotate_vaddr_range = 0x00524156,
        load_module = 0x00524157,
    };

    const DWORD = std.os.windows.DWORD;
    const BOOL = std.os.windows.BOOL;
    const HRESULT = i32;
    const HANDLE = std.os.windows.HANDLE;
    const HMODULE = std.os.windows.HMODULE;
    const LPCWSTR = std.os.windows.LPCWSTR;
    const FARPROC = std.os.windows.FARPROC;

    extern "kernel32" fn GetModuleHandleA(name: ?[*:0]const u8) callconv(.winapi) ?HMODULE;
    extern "kernel32" fn GetProcAddress(module: HMODULE, name: [*:0]const u8) callconv(.winapi) ?FARPROC;
    extern "kernel32" fn GetCurrentThread() callconv(.winapi) HANDLE;
    extern "kernel32" fn IsDebuggerPresent() callconv(.winapi) BOOL;
    extern "kernel32" fn RaiseException(code: DWORD, flags: DWORD, nargs: DWORD, args: ?[*]const usize) callconv(.winapi) void;
    extern "kernel32" fn OutputDebugStringA(str: [*:0]const u8) callconv(.winapi) void;

    const SetThreadDescriptionFn = *const fn (HANDLE, LPCWSTR) callconv(.winapi) HRESULT;

    const unresolved = 0;
    const missing = 1;
    var set_thread_description_cache: std.atomic.Value(usize) = .init(unresolved);

    /// Windows 10 1607+: Resolved on first use, racing threads all compute the same value so none wait
    fn setThreadDescription() ?SetThreadDescriptionFn {
        var cached = set_thread_description_cache.load(.acquire);
        if (cached == unresolved) {
            const proc = if (GetModuleHandleA("kernel32.dll")) |module| GetProcAddress(module, "SetThreadDescription") else null;
            cached = if (proc) |p| @intFromPtr(p) else missing;
            set_thread_description_cache.store(cached, .release);
        }
        return if (cached == missing) null else @ptrFromInt(cached);
    }

    fn raise(code: ExceptionCode, params: []const usize) void {
        RaiseException(@backingInt(code), 0, @intCast(params.len), params.ptr);
    }
} else struct {};

// ---

const testing = std.testing;

test "text matches what the C macros write" {
    // raddbg_type_view and raddbg_entry_point in raddbg_markup.h
    try testing.expectEqualStrings("type_view: {type: ```[]u8```, expr: ```array(ptr, len)```}", typeViewText("[]u8", "array(ptr, len)"));
    try testing.expectEqualStrings("type_view: {type: ```u32```, expr: ```x```}", typeViewText(u32, "x"));
    try testing.expectEqualStrings("entry_point: \"main\"", entryPointText("main"));
}

test "hasTracer reads TracerPid" {
    try testing.expect(!hasTracer("Name:\tt\nTracerPid:\t0\nUid:\t1000\n"));
    try testing.expect(hasTracer("Name:\tt\nTracerPid:\t4242\nUid:\t1000\n"));
    try testing.expect(!hasTracer("Name:\tt\nUid:\t1000\n"));
    try testing.expect(!hasTracer("TracerPid:"));
    try testing.expect(!hasTracer(""));
}

test "isAttached reads the marker byte" {
    if (!enabled) return error.SkipZigTest;
    // what the debugger does when it attaches
    const byte: *volatile u8 = &Marker.byte[0];
    byte.* = 1;
    defer byte.* = 0;
    try testing.expect(isAttached());
}

test "disabled markup does nothing" {
    if (enabled) return error.SkipZigTest;
    try testing.expect(!isAttached());
}

/// Section header named `name` in an ELF image
fn elfSection(image: []const u8, name: []const u8) !?std.elf.Elf64_Shdr {
    var reader = std.Io.Reader.fixed(image);
    const header = try std.elf.Header.read(&reader);

    var strings: []const u8 = &.{};
    var headers = header.iterateSectionHeadersBuffer(image);
    var index: usize = 0;
    while (try headers.next()) |shdr| : (index += 1) {
        if (index == header.shstrndx) strings = image[@intCast(shdr.sh_offset)..][0..@intCast(shdr.sh_size)];
    }

    headers = header.iterateSectionHeadersBuffer(image);
    while (try headers.next()) |shdr| {
        if (std.mem.eql(u8, std.mem.sliceTo(strings[shdr.sh_name..], 0), name)) return shdr;
    }
    return null;
}

// Checks the sections themselves: the strings are compile-time constants in the test binary too,
// so searching the whole file for them would also pass when `embed` writes nothing.
test "type views and entry points are written into the .raddbg section" {
    if (!enabled or builtin.object_format != .elf) return error.SkipZigTest;
    comptime typeView("[]markup_test_type", "array(ptr, len)");
    comptime entryPoint("markup_test_entry");

    const io = std.Io.Threaded.global_single_threaded.io();
    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const path = path_buffer[0..try std.process.executablePath(io, &path_buffer)];
    const image = try std.Io.Dir.cwd().readFileAlloc(io, path, testing.allocator, .limited(256 << 20));
    defer testing.allocator.free(image);

    const shdr = (try elfSection(image, ".raddbg")) orelse return error.TestUnexpectedResult;
    const data = image[@intCast(shdr.sh_offset)..][0..@intCast(shdr.sh_size)];
    try testing.expect(std.mem.indexOf(u8, data, typeViewText("[]markup_test_type", "array(ptr, len)")) != null);
    try testing.expect(std.mem.indexOf(u8, data, entryPointText("markup_test_entry")) != null);
}

test "the is-attached marker is one writable byte in .rdbgia" {
    if (!enabled or builtin.object_format != .elf) return error.SkipZigTest;

    const io = std.Io.Threaded.global_single_threaded.io();
    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const path = path_buffer[0..try std.process.executablePath(io, &path_buffer)];
    const image = try std.Io.Dir.cwd().readFileAlloc(io, path, testing.allocator, .limited(256 << 20));
    defer testing.allocator.free(image);

    const shdr = (try elfSection(image, ".rdbgia")) orelse return error.TestUnexpectedResult;
    try testing.expectEqual(1, shdr.sh_size);
    try testing.expect(shdr.sh_flags & std.elf.SHF_WRITE != 0);
    try testing.expect(shdr.sh_flags & std.elf.SHF_ALLOC != 0);
}

test "default views compile" {
    comptime std_views.registerDefaults();
}

test "packRgba matches the C macro for r, g, b" {
    try testing.expectEqual(0xffffffff, Rgba.pack(1, 1, 1, 1));
    try testing.expectEqual(0x00000000, Rgba.pack(0, 0, 0, 0));
    try testing.expectEqual(0xff6666ff, Rgba.pack(1, 0.4, 0.4, 1));
    try testing.expectEqual(0xffff667f, Rgba.pack(1, 1, 0.4, 0.5));
    try testing.expectEqual(0xff0000ff, Rgba.pack(2, -1, 0, 1)); // clamped
}
