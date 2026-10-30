const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const marker_key = "raddbg_markup:";
const begin_marker = marker_key ++ " begin";
const end_marker = marker_key ++ " end";
const raddbg_version: std.SemanticVersion = .{ .major = 0, .minor = 9, .patch = 30 }; // pull in from build?

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(arena);
    if (args.len != 3) std.process.fatal("usage: raddbg_project <markup-file> <project-file>", .{});
    const markup_file_path = args[1];
    const project_file_path = args[2];

    // input markup file is creatted by zig objcopy -j .raddbg -O binary ./ELF-FILE ./MARKUP-FILE.bin

    const cwd = Io.Dir.cwd();
    const markup = cwd.readFileAlloc(io, markup_file_path, arena, .unlimited) catch |err|
        std.process.fatal("failed to read {s}: {t}", .{ markup_file_path, err });
    const existing: []const u8 = cwd.readFileAlloc(io, project_file_path, arena, .unlimited) catch |err| switch (err) {
        error.FileNotFound => "",
        else => std.process.fatal("failed to read {s}: {t}", .{ project_file_path, err }),
    };

    const out = try update(arena, existing, markup);
    if (std.mem.eql(u8, out, existing)) return;

    // change, rewrite file
    cwd.writeFile(io, .{ .sub_path = project_file_path, .data = out }) catch |err|
        std.process.fatal("failed to write {s}: {t}", .{ project_file_path, err });
}

/// Returns the new project file contents. `markup` is the `.raddbg` section which is nulL separated entries
fn update(arena: Allocator, existing: []const u8, markup: []const u8) ![]const u8 {
    var block: std.ArrayList(u8) = .empty;
    var seen: std.StringHashMapUnmanaged(void) = .empty;
    var entries = std.mem.splitScalar(u8, markup, '\x00');

    while (entries.next()) |entry| {
        if (!isEntry(entry)) continue; // padding / linker leftovers
        if ((try seen.getOrPut(arena, entry)).found_existing) continue;

        if (isEntryPoint(entry)) {
            const target = try transformEntryPointToTarget(arena, entry);
            try block.appendSlice(arena, target);
        } else {
            try block.appendSlice(arena, entry);
        }
        try block.append(arena, '\n');
    }

    var head = existing;
    var tail: []const u8 = "";
    if (findMarker(existing, begin_marker, 0)) |begin| {
        const end = findMarker(existing, end_marker, begin.end) orelse return error.UnterminatedBlock;
        head = existing[0..begin.start];
        tail = existing[end.end..];
    }

    var out: std.ArrayList(u8) = .empty;
    // raddbg refuses to load a config file that doesn't start with this header
    if (!std.mem.startsWith(u8, existing, "// raddbg")) try out.appendSlice(arena, std.fmt.comptimePrint("// raddbg {f} project file\n\n", .{raddbg_version}));

    try out.appendSlice(arena, head);
    if (block.items.len != 0) {
        if (head.len != 0 and head[head.len - 1] != '\n') try out.append(arena, '\n');
        try out.appendSlice(arena, begin_marker ++ "\n");
        try out.appendSlice(arena, block.items);
        try out.appendSlice(arena, end_marker ++ "\n");
    }
    try out.appendSlice(arena, tail);

    return out.items;
}

const Line = struct { start: usize, end: usize };

fn findMarker(text: []const u8, marker: []const u8, from: usize) ?Line {
    std.debug.assert(std.mem.startsWith(u8, marker, marker_key));
    const marker_name = marker[marker_key.len + 1 ..];

    var start = from;
    while (start < text.len) {
        const end = if (std.mem.indexOfScalarPos(u8, text, start, '\n')) |newline| newline + 1 else text.len;
        const line = std.mem.trim(u8, text[start..end], " \t\r\n");
        if (std.mem.startsWith(u8, line, marker_key) and
            std.mem.eql(u8, std.mem.trim(u8, line[marker_key.len + 1 ..], " \t\""), marker_name))
        {
            return .{ .start = start, .end = end };
        }

        start = end;
    }

    return null;
}

fn isEntry(raw: []const u8) bool {
    if (!std.unicode.utf8ValidateSlice(raw)) return false;

    const type_view = std.mem.startsWith(u8, raw, "type_view: {type: ```") and std.mem.endsWith(u8, raw, "```}");
    const entry_point = isEntryPoint(raw);
    return type_view or entry_point;
}

fn isEntryPoint(raw: []const u8) bool {
    return std.mem.startsWith(u8, raw, "entry_point: \"") and std.mem.endsWith(u8, raw, "\"");
}

fn transformEntryPointToTarget(gpa: std.mem.Allocator, raw: []const u8) ![]const u8 {
    std.debug.assert(isEntryPoint(raw));

    const offset = (std.mem.indexOfScalar(u8, raw, '"') orelse return error.InvalidEntroypoint) + 1;
    const len = std.mem.indexOfScalar(u8, raw[offset..], '"') orelse return error.InvalidEntroypoint;
    const func_name = raw[offset .. offset + len];

    // TODO: need to fill out `executable` and `working_directory` and maybe `arguments` and `enabled`
    return gpa.print("target: {{ label: \"{0s}\", entry_point: \"{0s}\" }}", .{func_name});
}

const test_markup = "\x00type_view: {type: ```a```, expr: ```x```}\x00" ++
    "N\x02junk\x00entry_point: \"main.main\"\x00" ++
    "\x00type_view: {type: ```a```, expr: ```x```}\x00";

const test_block = begin_marker ++ "\n" ++
    "type_view: {type: ```a```, expr: ```x```}\n" ++
    "target: { label: \"main.main\", entry_point: \"main.main\" }\n" ++
    end_marker ++ "\n";

fn testUpdate(existing: []const u8) ![]const u8 {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    return std.testing.allocator.dupe(u8, try update(arena.allocator(), existing, test_markup));
}

test "new file gets header and block, duplicates and junk are dropped" {
    const out = try testUpdate("");
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("// raddbg 0.9.30 project file\n\n" ++ test_block, out);
}

test "block is replaced in place, other settings kept, rerun is a no-op" {
    const user = "breakpoint:\n{\n  source_location: \"src/main.zig:8:1\"\n}\n";
    const existing = "// raddbg 0.9.30 project file\n\n" ++ user ++
        begin_marker ++ "\n" ++ "type_view: {type: ```old```, expr: ```gone```}\n" ++ end_marker ++ "\n" ++
        "target:\n{\n  executable: \"zig-out/bin/app\"\n}\n";
    const out = try testUpdate(existing);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings(
        "// raddbg 0.9.30 project file\n\n" ++ user ++ test_block ++ "target:\n{\n  executable: \"zig-out/bin/app\"\n}\n",
        out,
    );
    const again = try testUpdate(out);
    defer std.testing.allocator.free(again);
    try std.testing.expectEqualStrings(out, again);
}

test "block is appended after content without a trailing newline" {
    const out = try testUpdate("// raddbg 0.9.30 project file\nfoo");
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("// raddbg 0.9.30 project file\nfoo\n" ++ test_block, out);
}

// what raddbg writes back after opening the file. Comments are stripped and it formats the items
const resaved_block = marker_key ++ " begin\n" ++
    "type_view:\n{\n  type: old\n  expr: \"rows($, gone)\"\n}\n" ++
    "target:\n{\n  label: old.main\n  entry_point: old.main\n}\n" ++
    marker_key ++ " end\n";

test "a block rewritten by raddbg is replaced, not duplicated" {
    const user = "breakpoint:\n{\n  source_location: \"src/main.zig:8:1\"\n}\n";
    const existing = "// raddbg 0.9.30 project file\n\n" ++ user ++ resaved_block ++ "target:\n{\n  label: app\n}\n";
    const out = try testUpdate(existing);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings(
        "// raddbg 0.9.30 project file\n\n" ++ user ++ test_block ++ "target:\n{\n  label: app\n}\n",
        out,
    );
}

test "markers are found with quoted values, and only as whole lines" {
    const quoted = "raddbg_markup: \"begin\"\nold\nraddbg_markup: \"end\"\n";
    const out = try testUpdate(quoted);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings("// raddbg 0.9.30 project file\n\n" ++ test_block, out);

    // a view that mentions the marker text is not a marker
    try std.testing.expect(findMarker("type_view: {type: ```raddbg_markup: begin```}\n", begin_marker, 0) == null);
}

test "unterminated block is an error" {
    try std.testing.expectError(error.UnterminatedBlock, testUpdate("// raddbg x\n" ++ begin_marker));
}
