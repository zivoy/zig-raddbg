const std = @import("std");
const raddbg = @import("markup.zig");

pub fn registerDefaults() void {
    slices();
    arrayLists();
}

pub fn slices() void {
    raddbg.typeView("[]?", "array(ptr, len)");
    raddbg.typeView("[:?]?", "array(ptr, len)");
}

pub fn arrayLists() void {
    raddbg.typeView("array_list.Aligned(?)", "rows($, items, items.len, capacity)");
    raddbg.typeView("array_list.AlignedManaged(?)", "rows($, items, items.len, capacity)");
}
