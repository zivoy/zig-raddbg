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
    linkedLists();
    io();
    errors();
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

pub fn multiArrayListOf(comptime T: type) void {
    const info = @typeInfo(T).@"struct";
    var rows: []const u8 = "";
    for (columnLayout(T)) |column| {
        const size = @sizeOf(info.field_types[column.field]);
        if (size == 0) continue;

        // there are some issues with raddbg, so I can't cast to the correct type and use array, so for now it will be be memory
        rows = rows ++ std.fmt.comptimePrint(", {s} = memory(bytes + capacity * {d}, size = len * {d})", .{ info.field_names[column.field], column.offset, size });
    }

    raddbg.typeView(std.MultiArrayList(T), "rows($, len, capacity, bytes" ++ rows ++ ")");
}

const Column = struct { field: usize, offset: usize };

fn columnLayout(comptime T: type) [@typeInfo(T).@"struct".field_names.len]Column {
    const info = @typeInfo(T).@"struct";
    var order: [info.field_names.len]usize = undefined;
    for (&order, 0..) |*slot, i| slot.* = i;
    const Sort = struct {
        fn alignment(field: usize) usize {
            return info.field_attrs[field].@"align" orelse @alignOf(info.field_types[field]);
        }
        fn lessThan(_: void, a: usize, b: usize) bool {
            return alignment(a) > alignment(b);
        }
    };
    std.mem.sort(usize, &order, {}, Sort.lessThan);

    var layout: [order.len]Column = undefined;
    var offset: usize = 0;
    for (order, 0..) |field, i| {
        layout[i] = .{ .field = field, .offset = offset };
        offset += @sizeOf(info.field_types[field]);
    }
    return layout;
}

pub fn linkedLists() void {
    raddbg.typeView(std.SinglyLinkedList, "list(first, next)");
    raddbg.typeView(std.DoublyLinkedList, "list(first, next)");
}

pub fn io() void {
    raddbg.typeView(std.Io.Writer, "array(buffer.ptr, end)");
    raddbg.typeView(std.Io.Reader, "array(buffer.ptr + seek, end - seek)");
    raddbg.typeView(std.Io.Writer.Allocating, "writer");
}

pub fn errors() void {
    raddbg.typeView("error{?}!?", "rows($, error, payload)");
    raddbg.typeView("anyerror!?", "rows($, error, payload)");
}

// cant really register optional, since `?` is the wildcard, but it should be fine, a `?T` is just struct that has `{ payload, some }` and a `?[]T` is an array that can have its ptr be 0
