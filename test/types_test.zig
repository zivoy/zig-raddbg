const std = @import("std");
const raddbg = @import("raddbg");

comptime {
    raddbg.std_views.registerDefaults();
    raddbg.entryPoint("add");
}

const Color = enum { red, green, blue };
const Small = enum(u8) { a = 1, b = 2, c = 200 };
const Open = enum(u8) { x = 0, y = 1, _ };

const Vec3 = struct { x: f32, y: f32, z: f32 };
const Packed = packed struct { a: u3, b: bool, c: u4 };
const Extern = extern struct { id: u32, weight: f64, tag: [4]u8 };
const Nested = struct { name: []const u8, pos: Vec3, tags: [3]Color, next: ?*const Nested };

const Bare = union { int: i64, float: f64, bytes: [8]u8 };
const Tagged = union(enum) { none, int: i64, text: []const u8, vec: Vec3 };
const ExternUnion = extern union { i: u32, f: f32 };
const PackedUnion = packed union { whole: u16, parts: packed struct { lo: u8, hi: u8 } };

const Opaque = opaque {};
const MyError = error{ OutOfBounds, Nope };

fn add(a: i32, b: i32) i32 {
    return a + b;
}

var pointable_u32: u32 = 1234;

fn lessThan(_: void, a: u32, b: u32) std.math.Order {
    return std.math.order(a, b);
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();

    // integers & floats
    var zero_bits: u0 = 0;
    var odd_width: u7 = 100;
    var int_8: i8 = -5;
    var uint_8: u8 = 'z';
    var int_32: i32 = -123456;
    var uint_64: u64 = 0xdead_beef_cafe;
    var int_128: i128 = -(1 << 100);
    var usize_val: usize = 4096;
    var float_16: f16 = 1.5;
    var float_32: f32 = 3.14159;
    var float_64: f64 = 2.718281828459045;
    var float_80: f80 = 1.25;
    var float_128: f128 = 0.1;
    var bool_val: bool = true;
    var void_val: void = {};
    var cint: c_int = -7;
    var cchar: c_char = 'q';

    // optionals, errors
    var opt_some: ?u32 = 42;
    var opt_none: ?u32 = null;
    var opt_ptr: ?*const u32 = &pointable_u32;
    var opt_ptr_null: ?*const u32 = null;
    var err_ok: MyError!u32 = 7;
    var err_bad: MyError!u32 = MyError.OutOfBounds;
    var err_any: anyerror = error.Nope;
    var opt_err: ?MyError!u8 = null;
    var opt_slice: ?[]const u8 = "hi";
    var opt_slice_null: ?[]const u8 = null;
    var err_slice: MyError![]const u8 = "ok";
    var opt_vec: ?[]Vec3 = null;

    // enums
    var enum_1: Color = .green;
    var enum_2: Small = .c;
    var enum_3: Open = @fromBackingInt(@intCast(77)); // non-exhaustive, unnamed value

    // structs & unions
    var vec: Vec3 = .{ .x = 1, .y = 2, .z = 3 };
    var packed_struct: Packed = .{ .a = 5, .b = true, .c = 9 };
    var extern_struct: Extern = .{ .id = 7, .weight = 0.5, .tag = "abcd".* };
    var leaf: Nested = .{ .name = "leaf", .pos = vec, .tags = .{ .red, .green, .blue }, .next = null };
    var root: Nested = .{ .name = "root", .pos = vec, .tags = .{ .blue, .blue, .red }, .next = &leaf };
    var union_bare: Bare = .{ .float = 1.5 };
    var union_tag_none: Tagged = .none;
    var union_tag_text: Tagged = .{ .text = "tagged text" };
    var union_tag_vec: Tagged = .{ .vec = vec };
    var union_ext: ExternUnion = .{ .f = 1.0 };
    var union_pk: PackedUnion = .{ .whole = 0xabcd };
    var tuple_u8: u8 = 1;
    var tuple_f32: f32 = 2.5;
    var tuple = .{ tuple_u8, tuple_f32 };

    // pointers
    var target: u32 = 99;
    var pointer_one: *u32 = &target;
    var pointer_const: *const u32 = &target;
    var pointer_pointer: **u32 = &pointer_one;
    var pointer_vec: *const Vec3 = &vec;
    var pointer_any: *const anyopaque = &target;
    var pointer_opaque: ?*Opaque = null;
    var pointer_fn: *const fn (i32, i32) i32 = &add;

    // arrays
    var array_ints = [_]u8{ 1, 2, 3, 4, 5 };
    var array_sentinel = [_:0]u8{ 'h', 'i', '!' };
    var array_empty = [_]u32{};
    var array_2d = [3][3]i16{ .{ 1, 2, 3 }, .{ 4, 5, 6 }, .{ 7, 8, 9 } };
    var array_vecs = [_]Vec3{ vec, .{ .x = 4, .y = 5, .z = 6 } };
    var array_big: [300]u8 = @splat(0xAA);
    var array_str = [_][]const u8{ "alpha", "beta", "gamma" };

    // many-pointers, C pointers, slices
    var many: [*]const u8 = &array_ints;
    var many_sent: [*:0]const u8 = &array_sentinel;
    var c_ptr: [*c]const u8 = &array_ints;
    var c_ptr_null: [*c]const u8 = null;
    var sl: []const u8 = array_ints[1..4];
    var sl_mut: []u8 = @constCast(array_ints[0..2]);
    var sl_sent: [:0]const u8 = "sentinel slice";
    var sl_empty: []const u32 = &.{};
    var sl_vec: []const Vec3 = &array_vecs;
    var sl_of_sl: []const []const u8 = &array_str;
    var text: []const u8 = "hello, raddbg";

    // vectors
    var vec4: @Vector(4, f32) = .{ 1, 2, 3, 4 };
    var vec_int: @Vector(8, u8) = @splat(7);
    var vec_bool: @Vector(4, bool) = .{ true, false, true, false };

    // --- std containers ---

    // array lists
    var array_list: std.ArrayList(u32) = .empty;
    try array_list.appendSlice(gpa, &.{ 10, 20, 30, 40 });
    var array_list_empty: std.ArrayList(u32) = .empty;
    var array_list_vec: std.ArrayList(Vec3) = .empty;
    try array_list_vec.append(gpa, vec);
    var array_list_aligned: std.array_list.Aligned(u8, .@"16") = .empty;
    try array_list_aligned.appendSlice(gpa, "aligned");
    var array_list_managed = std.array_list.Managed(u16).init(gpa);
    try array_list_managed.appendSlice(&.{ 1, 2, 3 });

    // queues
    var priority_queue: std.PriorityQueue(u32, void, lessThan) = .empty;
    for ([_]u32{ 5, 1, 9, 3 }) |v| try priority_queue.push(gpa, v);
    var priority_dequeue: std.PriorityDequeue(u32, void, lessThan) = .empty;
    for ([_]u32{ 8, 2, 6 }) |v| try priority_dequeue.push(gpa, v);
    var deque: std.Deque(u32) = .empty;
    try deque.pushBack(gpa, 1);
    try deque.pushBack(gpa, 2);
    try deque.pushFront(gpa, 0);

    // hash maps
    var hashmap = std.AutoHashMap(u32, []const u8).init(gpa);
    try hashmap.put(1, "one");
    try hashmap.put(2, "two");
    var string_hashmap = std.StringHashMap(u32).init(gpa);
    try string_hashmap.put("a", 1);
    try string_hashmap.put("b", 2);
    var hashmap_unmanaged: std.AutoHashMapUnmanaged(u8, u8) = .empty;
    try hashmap_unmanaged.put(gpa, 1, 2);
    var auto_hashmap: std.array_hash_map.Auto(u32, u32) = .empty;
    try auto_hashmap.put(gpa, 3, 30);
    try auto_hashmap.put(gpa, 1, 10);
    var string_array_hashmap: std.array_hash_map.String(f32) = .empty;
    try string_array_hashmap.put(gpa, "pi", 3.14);
    var buf_map = std.BufMap.init(gpa);
    try buf_map.put("key", "value");
    var buf_set = std.BufSet.init(gpa);
    try buf_set.insert("member");

    // bit sets
    var bitset_int: std.bit_set.Integer(20) = .empty;
    bitset_int.set(3);
    bitset_int.set(17);
    var bitsset_array: std.bit_set.Array(u64, 200) = .empty;
    bitsset_array.set(1);
    bitsset_array.set(130);
    var bitset_dynamic = try std.DynamicBitSetUnmanaged.initEmpty(gpa, 100);
    bitset_dynamic.set(0);
    bitset_dynamic.set(99);
    var bitset_dynamic_managed = try std.DynamicBitSet.initEmpty(gpa, 70);
    bitset_dynamic_managed.set(69);
    var enum_set = std.EnumSet(Color).init(.{ .red = true, .blue = true });
    var enum_map = std.EnumMap(Color, u32).init(.{ .red = 1, .blue = 3 });
    var enum_array = std.EnumArray(Color, u8).initFill(9);

    // other containers
    var multi_array_list: std.MultiArrayList(Vec3) = .empty;
    try multi_array_list.append(gpa, vec);
    try multi_array_list.append(gpa, .{ .x = 7, .y = 8, .z = 9 });
    var singly_linked_list: std.SinglyLinkedList = .{};
    var singly_linked_list_node1: std.SinglyLinkedList.Node = .{};
    var singly_linked_list_node2: std.SinglyLinkedList.Node = .{};
    singly_linked_list.prepend(&singly_linked_list_node1);
    singly_linked_list.prepend(&singly_linked_list_node2);
    var doubly_linked_list: std.DoublyLinkedList = .{};
    var doubly_linked_list_node1: std.DoublyLinkedList.Node = .{};
    var doubly_linked_list_node2: std.DoublyLinkedList.Node = .{};
    doubly_linked_list.append(&doubly_linked_list_node1);
    doubly_linked_list.append(&doubly_linked_list_node2);

    // io
    var write_buf: [64]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&write_buf);
    try writer.print("buffered {d}", .{123});
    var reader: std.Io.Reader = .fixed("reader contents here");
    _ = try reader.takeByte();
    _ = try reader.takeByte();
    var alloc_writer: std.Io.Writer.Allocating = .init(gpa);
    try alloc_writer.writer.writeAll("allocating writer");

    // misc std
    var prng = std.Random.DefaultPrng.init(0xC0FFEE);
    var version = std.SemanticVersion{ .major = 1, .minor = 2, .patch = 3, .pre = "rc1" };
    var allocator: std.mem.Allocator = gpa;
    var io: std.Io = init.io; // Io.Threaded from the juicy main

    @breakpoint();

    std.mem.doNotOptimizeAway(.{ &opt_some, &opt_none, &err_ok, &err_bad, &opt_err, &vec, &packed_struct, &leaf, &root, &union_bare, &union_tag_none, &union_tag_text, &union_tag_vec, &union_ext, &union_pk, &tuple, &tuple_u8, &tuple_f32, &array_ints, &array_sentinel, &array_empty, &array_2d, &array_vecs, &array_big, &array_str, &vec4, &vec_bool, &zero_bits, &odd_width, &int_8, &uint_8, &int_32, &uint_64, &int_128, &usize_val, &float_16, &float_32, &float_64, &float_80, &float_128, &bool_val, &void_val, &cint, &cchar, &opt_ptr, &opt_ptr_null, &err_any, &enum_1, &enum_2, &enum_3, &extern_struct, &pointer_const, &pointer_pointer, &pointer_vec, &pointer_any, &pointer_opaque, &pointer_fn, &many, &many_sent, &c_ptr, &c_ptr_null, &sl, &sl_mut, &sl_sent, &sl_empty, &sl_vec, &sl_of_sl, &text, &vec_int, &version, &allocator, zero_bits, odd_width, int_8, uint_8, int_32, uint_64, int_128, usize_val, float_16, float_32, float_64, float_80, float_128, bool_val, void_val, cint, cchar, opt_some, opt_none, opt_ptr, opt_ptr_null, err_ok, err_bad, err_any, opt_err, enum_1, enum_2, enum_3, vec, packed_struct, extern_struct, root, union_bare, union_tag_none, union_tag_text, union_tag_vec, union_ext, union_pk, tuple, pointer_one, pointer_const, pointer_pointer, pointer_vec, pointer_any, pointer_opaque, pointer_fn, array_ints, array_sentinel, array_empty, array_2d, array_vecs, array_big, array_str, many, many_sent, c_ptr, c_ptr_null, sl, sl_mut, sl_sent, sl_empty, sl_vec, sl_of_sl, text, vec4, vec_int, vec_bool, &array_list, &array_list_empty, &array_list_vec, &array_list_aligned, &array_list_managed, &priority_queue, &priority_dequeue, &deque, &hashmap, &string_hashmap, &hashmap_unmanaged, &auto_hashmap, &string_array_hashmap, &buf_map, &buf_set, &bitset_int, &bitsset_array, &bitset_dynamic, &bitset_dynamic_managed, &enum_set, &enum_map, &enum_array, &multi_array_list, &singly_linked_list, &doubly_linked_list, &writer, &reader, &alloc_writer, &prng, version, allocator, &opt_slice, &opt_slice_null, &err_slice, &opt_vec, &io });

    std.debug.print("done: {s}\n", .{text});
}
