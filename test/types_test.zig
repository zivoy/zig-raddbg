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
    var i8v: i8 = -5;
    var u8v: u8 = 'z';
    var i32v: i32 = -123456;
    var u64v: u64 = 0xdead_beef_cafe;
    var i128v: i128 = -(1 << 100);
    var usizev: usize = 4096;
    var f16v: f16 = 1.5;
    var f32v: f32 = 3.14159;
    var f64v: f64 = 2.718281828459045;
    var f80v: f80 = 1.25;
    var f128v: f128 = 0.1;
    var bv: bool = true;
    var vd: void = {};
    var cint: c_int = -7;
    var cchar: u8 = 'q';

    // optionals, errors
    var opt_some: ?u32 = 42;
    var opt_none: ?u32 = null;
    var opt_ptr: ?*const u32 = &pointable_u32;
    var opt_ptr_null: ?*const u32 = null;
    var err_ok: MyError!u32 = 7;
    var err_bad: MyError!u32 = MyError.OutOfBounds;
    var err_any: anyerror = error.Nope;
    var opt_err: ?MyError!u8 = null;

    // enums
    var e1: Color = .green;
    var e2: Small = .c;
    var e3: Open = @fromBackingInt(@intCast(77)); // non-exhaustive, unnamed value

    // structs & unions
    var vec: Vec3 = .{ .x = 1, .y = 2, .z = 3 };
    var pk: Packed = .{ .a = 5, .b = true, .c = 9 };
    var ex: Extern = .{ .id = 7, .weight = 0.5, .tag = "abcd".* };
    var leaf: Nested = .{ .name = "leaf", .pos = vec, .tags = .{ .red, .green, .blue }, .next = null };
    var root: Nested = .{ .name = "root", .pos = vec, .tags = .{ .blue, .blue, .red }, .next = &leaf };
    var un_bare: Bare = .{ .float = 1.5 };
    var un_tag_none: Tagged = .none;
    var un_tag_text: Tagged = .{ .text = "tagged text" };
    var un_tag_vec: Tagged = .{ .vec = vec };
    var un_ext: ExternUnion = .{ .f = 1.0 };
    var un_pk: PackedUnion = .{ .whole = 0xabcd };
    var tuple_u8: u8 = 1;
    var tuple_f32: f32 = 2.5;
    var tuple = .{ tuple_u8, tuple_f32 };

    // pointers
    var target: u32 = 99;
    var p_one: *u32 = &target;
    var p_const: *const u32 = &target;
    var p_pp: **u32 = &p_one;
    var p_vec: *const Vec3 = &vec;
    var p_any: *const anyopaque = &target;
    var p_opaque: ?*Opaque = null;
    var p_fn: *const fn (i32, i32) i32 = &add;

    // arrays
    var arr_ints = [_]u8{ 1, 2, 3, 4, 5 };
    var arr_sentinel = [_:0]u8{ 'h', 'i', '!' };
    var arr_empty = [_]u32{};
    var arr_2d = [3][3]i16{ .{ 1, 2, 3 }, .{ 4, 5, 6 }, .{ 7, 8, 9 } };
    var arr_vecs = [_]Vec3{ vec, .{ .x = 4, .y = 5, .z = 6 } };
    var arr_big: [300]u8 = @splat(0xAA);
    var arr_str = [_][]const u8{ "alpha", "beta", "gamma" };

    // many-pointers, C pointers, slices
    var many: [*]const u8 = &arr_ints;
    var many_sent: [*:0]const u8 = &arr_sentinel;
    var c_ptr: [*c]const u8 = &arr_ints;
    var c_ptr_null: [*c]const u8 = null;
    var sl: []const u8 = arr_ints[1..4];
    var sl_mut: []u8 = @constCast(arr_ints[0..2]);
    var sl_sent: [:0]const u8 = "sentinel slice";
    var sl_empty: []const u32 = &.{};
    var sl_vec: []const Vec3 = &arr_vecs;
    var sl_of_sl: []const []const u8 = &arr_str;
    var text: []const u8 = "hello, raddbg";

    // vectors
    var vec4: @Vector(4, f32) = .{ 1, 2, 3, 4 };
    var vec_int: @Vector(8, u8) = @splat(7);
    var vec_bool: @Vector(4, bool) = .{ true, false, true, false };

    // --- std containers ---

    // array lists
    var al: std.ArrayList(u32) = .empty;
    try al.appendSlice(gpa, &.{ 10, 20, 30, 40 });
    var al_empty: std.ArrayList(u32) = .empty;
    var al_vec: std.ArrayList(Vec3) = .empty;
    try al_vec.append(gpa, vec);
    var al_aligned: std.array_list.Aligned(u8, .@"16") = .empty;
    try al_aligned.appendSlice(gpa, "aligned");
    var al_managed = std.array_list.Managed(u16).init(gpa);
    try al_managed.appendSlice(&.{ 1, 2, 3 });

    // queues
    var pq: std.PriorityQueue(u32, void, lessThan) = .empty;
    for ([_]u32{ 5, 1, 9, 3 }) |v| try pq.push(gpa, v);
    var pdq: std.PriorityDequeue(u32, void, lessThan) = .empty;
    for ([_]u32{ 8, 2, 6 }) |v| try pdq.push(gpa, v);
    var dq: std.Deque(u32) = .empty;
    try dq.pushBack(gpa, 1);
    try dq.pushBack(gpa, 2);
    try dq.pushFront(gpa, 0);

    // hash maps
    var hm = std.AutoHashMap(u32, []const u8).init(gpa);
    try hm.put(1, "one");
    try hm.put(2, "two");
    var shm = std.StringHashMap(u32).init(gpa);
    try shm.put("a", 1);
    try shm.put("b", 2);
    var hm_unmanaged: std.AutoHashMapUnmanaged(u8, u8) = .empty;
    try hm_unmanaged.put(gpa, 1, 2);
    var ahm: std.array_hash_map.Auto(u32, u32) = .empty;
    try ahm.put(gpa, 3, 30);
    try ahm.put(gpa, 1, 10);
    var sahm: std.array_hash_map.String(f32) = .empty;
    try sahm.put(gpa, "pi", 3.14);
    var buf_map = std.BufMap.init(gpa);
    try buf_map.put("key", "value");
    var buf_set = std.BufSet.init(gpa);
    try buf_set.insert("member");

    // bit sets
    var bs_int: std.bit_set.Integer(20) = .empty;
    bs_int.set(3);
    bs_int.set(17);
    var bs_arr: std.bit_set.Array(u64, 200) = .empty;
    bs_arr.set(1);
    bs_arr.set(130);
    var bs_dyn = try std.DynamicBitSetUnmanaged.initEmpty(gpa, 100);
    bs_dyn.set(0);
    bs_dyn.set(99);
    var bs_dyn_managed = try std.DynamicBitSet.initEmpty(gpa, 70);
    bs_dyn_managed.set(69);
    var enum_set = std.EnumSet(Color).init(.{ .red = true, .blue = true });
    var enum_map = std.EnumMap(Color, u32).init(.{ .red = 1, .blue = 3 });
    var enum_array = std.EnumArray(Color, u8).initFill(9);

    // other containers
    var mal: std.MultiArrayList(Vec3) = .empty;
    try mal.append(gpa, vec);
    try mal.append(gpa, .{ .x = 7, .y = 8, .z = 9 });
    var sll: std.SinglyLinkedList = .{};
    var sn1: std.SinglyLinkedList.Node = .{};
    var sn2: std.SinglyLinkedList.Node = .{};
    sll.prepend(&sn1);
    sll.prepend(&sn2);
    var dll: std.DoublyLinkedList = .{};
    var dn1: std.DoublyLinkedList.Node = .{};
    var dn2: std.DoublyLinkedList.Node = .{};
    dll.append(&dn1);
    dll.append(&dn2);

    // io
    var wbuf: [64]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&wbuf);
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

    @breakpoint();

    std.mem.doNotOptimizeAway(.{ &opt_some, &opt_none, &err_ok, &err_bad, &opt_err, &vec, &pk, &leaf, &root, &un_bare, &un_tag_none, &un_tag_text, &un_tag_vec, &un_ext, &un_pk, &tuple, &tuple_u8, &tuple_f32, &arr_ints, &arr_sentinel, &arr_empty, &arr_2d, &arr_vecs, &arr_big, &arr_str, &vec4, &vec_bool });

    std.mem.doNotOptimizeAway(.{ &zero_bits, &odd_width, &i8v, &u8v, &i32v, &u64v, &i128v, &usizev, &f16v, &f32v, &f64v, &f80v, &f128v, &bv, &vd, &cint, &cchar, &opt_ptr, &opt_ptr_null, &err_any, &e1, &e2, &e3, &ex, &p_const, &p_pp, &p_vec, &p_any, &p_opaque, &p_fn, &many, &many_sent, &c_ptr, &c_ptr_null, &sl, &sl_mut, &sl_sent, &sl_empty, &sl_vec, &sl_of_sl, &text, &vec_int, &version, &allocator });

    std.mem.doNotOptimizeAway(.{
        zero_bits,    odd_width,   i8v,      u8v,         i32v,          u64v,            i128v,      usizev,        f16v,        f32v,
        f64v,         f80v,        f128v,    bv,          vd,            cint,            cchar,      opt_some,      opt_none,    opt_ptr,
        opt_ptr_null, err_ok,      err_bad,  err_any,     opt_err,       e1,              e2,         e3,            vec,         pk,
        ex,           root,        un_bare,  un_tag_none, un_tag_text,   un_tag_vec,      un_ext,     un_pk,         tuple,       p_one,
        p_const,      p_pp,        p_vec,    p_any,       p_opaque,      p_fn,            arr_ints,   arr_sentinel,  arr_empty,   arr_2d,
        arr_vecs,     arr_big,     arr_str,  many,        many_sent,     c_ptr,           c_ptr_null, sl,            sl_mut,      sl_sent,
        sl_empty,     sl_vec,      sl_of_sl, text,        vec4,          vec_int,         vec_bool,   &al,           &al_empty,   &al_vec,
        &al_aligned,  &al_managed, &pq,      &pdq,        &dq,           &hm,             &shm,       &hm_unmanaged, &ahm,        &sahm,
        &buf_map,     &buf_set,    &bs_int,  &bs_arr,     &bs_dyn,       &bs_dyn_managed, &enum_set,  &enum_map,     &enum_array, &mal,
        &sll,         &dll,        &writer,  &reader,     &alloc_writer, &prng,           version,    allocator,
    });

    std.debug.print("done: {s}\n", .{text});
}
