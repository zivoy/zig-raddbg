const std = @import("std");
const raddbg = @import("markup.zig");

pub fn registerDefaults() void {
    slices();
    arrayLists();
    misc();
}

pub fn slices() void {
    raddbg.typeView("[]?", "array(ptr, len)");
    raddbg.typeView("[:?]?", "array(ptr, len)");
}

pub fn arrayLists() void {
    raddbg.typeView("array_list.Aligned(?)", "rows($, items, items.len, capacity)");
    raddbg.typeView("array_list.AlignedManaged(?)", "rows($, items, items.len, capacity)");
}

pub fn misc() void {
    // we cant register ?[]const u8 (pre and build), because the ? is the catch all, so nullable types have this issues
    raddbg.typeView(std.SemanticVersion, "rows($, major, minor, patch, pre = array(pre.ptr, pre.len), build = array(build.ptr, build.len))");
}
