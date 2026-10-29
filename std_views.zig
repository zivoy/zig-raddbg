const std = @import("std");
const raddbg = @import("markup.zig");

pub fn registerDefaults() void {
    slices();
    arrayLists();
    misc();
    queues();
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

pub fn queues() void {
    raddbg.typeView("priority_queue.PriorityQueue(?)", "rows($, items, items.len, cap)");
    raddbg.typeView("priority_dequeue.PriorityDequeue(?)", "rows($, heap = array(items.ptr, len), len, cap = items.len)");

    const deque_front = "(head + len > buffer.len ? buffer.len - head : len)";
    const deque_view = "rows($, " ++
        "front = array(buffer.ptr + head, " ++ deque_front ++ "), " ++
        "wrapped = array(buffer.ptr, len - " ++ deque_front ++ "), " ++
        "head, len)";
    raddbg.typeView("deque.Deque(?)", deque_view);
}
