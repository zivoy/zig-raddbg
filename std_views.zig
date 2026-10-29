const std = @import("std");
const raddbg = @import("markup.zig");

pub fn registerDefaults() void {
    slices();
    arrayLists();
    misc();
    queues();
    hashMaps();
    bitSets();
    enumContainers();
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

pub fn hashMaps() void {
    raddbg.typeView("array_hash_map.Custom(?)", "rows($, count = entries.len, capacity = entries.capacity, index_header, storage = array(entries.bytes,entries.len))");

    raddbg.typeView("hash_map.Custom(?,80)", hashMapView(""));
    raddbg.typeView("hash_map.HashMap(?,80)", hashMapView("unmanaged."));
    raddbg.typeView(std.BufMap, hashMapView("hash_map.unmanaged."));
    raddbg.typeView(std.BufSet, hashMapView("hash_map.unmanaged."));
}

// capacity is a power of two and `available` = floor(capacity * 80 / 100) - size, so (size + available) * 5 / 4 + 1 recovers it (default max load of 80%)
fn hashMapView(comptime prefix: []const u8) []const u8 {
    const live = "(" ++ prefix ++ "size + " ++ prefix ++ "available)";
    const capacity = live ++ " * 5 / 4 + 1";
    return "rows($, count = " ++ prefix ++ "size, available = " ++ prefix ++ "available, capacity = " ++ capacity ++
        ", slots = array(" ++ prefix ++ "metadata, " ++ capacity ++ "))";
}

pub fn bitSets() void {
    raddbg.typeView("bit_set.Integer(?)", "bin(bits)");
    raddbg.typeView("bit_set.Array(?)", "bin(masks)");
    raddbg.typeView(std.bit_set.Dynamic, "rows($, bit_length, bin(array(masks, (bit_length + 63) / 64)))");
    raddbg.typeView(std.bit_set.DynamicManaged, "unmanaged");
}

pub fn enumContainers() void {
    raddbg.typeView("enums.EnumSet(?)", "bin(bits.bits)");
    raddbg.typeView("enums.EnumMap(?)", "rows($, values, bin(bits.bits))");
    raddbg.typeView("enums.EnumArray(?)", "no_char(values)");
}
