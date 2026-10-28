const std = @import("std");
const raddbg = @import("raddbg");

const Vec3 = struct { x: f32, y: f32, z: f32 };

comptime {
    raddbg.typeView("[]?", "array(ptr, len)");
    raddbg.typeView("array_list.Aligned(?)", "rows($, items, items.len, capacity)");
    raddbg.typeView(Vec3, "rows($, x, y, z)");
    raddbg.typeView(Vec3, "rows($, x, y, z)"); // duplicate, should dedupe

    raddbg.entryPoint(@This(), "main");
}

pub fn main(init: std.process.Init) void {
    const allocator = init.arena.allocator();

    var al: std.ArrayList(u8) = .empty;
    al.appendSlice(allocator, "hi") catch unreachable;

    var vec: Vec3 = .{ .x = 1, .y = 0, .z = 20 };
    vec.y = (vec.x + vec.z) / 7;
    al.print(allocator, " - {any}", .{vec}) catch unreachable;

    std.debug.print("{s}\n", .{al.items});
}
