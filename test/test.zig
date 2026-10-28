const std = @import("std");
const raddbg = @import("raddbg");

comptime {
    raddbg.typeView("[]?", "array(ptr, len)");
    raddbg.typeView("array_list.Aligned(?)", "rows($, items, items.len, capacity)");
}
pub fn main(init: std.process.Init) void {
    const allocator = init.arena.allocator();

    var al: std.ArrayList(u8) = .empty;
    al.appendSlice(allocator, "hi") catch unreachable;

    std.debug.print("{s}\n", .{al.items});
}
