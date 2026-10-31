const std = @import("std");
const raddbg = @import("raddbg");
const Io = std.Io;

const Stage = enum {
    name,
    colour,
};

const colours_u32 = [worker_count]u32{ 0xE06C75FF, 0x98C379FF, 0x61AFEFFF, 0xE5C07BFF };
const colours_rgba = [worker_count][4]f32{
    .{ 1, 0.4, 0.4, 1 },
    .{ 0.4, 1, 0.4, 1 },
    .{ 0.4, 0.4, 1, 1 },
    .{ 1, 1, 0.4, 0.5 }, // fractional alpha, the C macro casts `a` before scaling so it would be 0 there
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    std.debug.print("debugger is {s}\n", .{if (raddbg.isAttached()) "attached" else "not attached"});

    var gate: Gate = .{};
    const threads = try spawnWorkers(stagedSelf, io, &gate);

    raddbg.log("--- thread name ---", .{});
    raddbg.threadName("main", .{});
    gate.run(io, .name);
    checkpoint();

    raddbg.log("--- thread name id ---", .{});
    for (gate.ids, 0..) |id, index| raddbg.threadIdName(id, "remote {d}", .{index});
    raddbg.threadIdName(raddbg.threadId(), "main by id", .{});
    raddbg.log("threads named by main", .{});
    checkpoint();

    raddbg.log("--- thread colour ---", .{});
    raddbg.threadColorRgba(1, 1, 1, 1);
    gate.run(io, .colour);
    checkpoint();

    raddbg.log("--- thread colour id ---", .{});
    for (gate.ids, 0..) |id, index| {
        // opposite polarity; odd workers use the u32 palette, even workers the rgba palette
        if (index % 2 == 1) {
            raddbg.threadIdColorU32(id, colours_u32[index]);
        } else {
            const c = colours_rgba[index];
            raddbg.threadIdColorRgba(id, c[0], c[1], c[2], c[3]);
        }
    }
    raddbg.threadIdColorU32(raddbg.threadId(), 0xffffffff);
    raddbg.log("threads coloured by main", .{});
    checkpoint();

    gate.quit.set(io);
    joinAll(threads);

    std.debug.print("done\n", .{});
}

inline fn checkpoint() void {
    raddbg.breakpointIf(raddbg.isAttached());
}

const worker_count = 4;

const Gate = struct {
    ids: [worker_count]std.Thread.Id = undefined,
    go: std.EnumArray(Stage, Io.Event) = .initFill(.unset),
    done: std.EnumArray(Stage, [worker_count]Io.Event) = .initFill(@splat(.unset)),
    quit: Io.Event = .unset,

    fn run(gate: *Gate, io: Io, stage: Stage) void {
        gate.go.getPtr(stage).set(io);
        for (gate.done.getPtr(stage)) |*event| event.waitUncancelable(io);
    }
};

fn spawnWorkers(comptime function: anytype, io: Io, gate: *Gate) ![worker_count]std.Thread {
    var threads: [worker_count]std.Thread = undefined;
    for (&threads, 0..) |*thread, idx| thread.* = try std.Thread.spawn(.{}, function, .{ io, gate, idx });
    return threads;
}

fn joinAll(threads: [worker_count]std.Thread) void {
    for (threads) |thread| thread.join();
}

// ---

fn stagedSelf(io: Io, gate: *Gate, index: usize) void {
    gate.ids[index] = raddbg.threadId();
    for (std.enums.values(Stage)) |stage| {
        gate.go.getPtr(stage).waitUncancelable(io);
        switch (stage) {
            .name => nameSelf(index),
            .colour => colourSelf(index),
        }
        gate.done.getPtr(stage)[index].set(io);
    }
    gate.quit.waitUncancelable(io);
}

fn nameSelf(index: usize) void {
    switch (index) {
        // linux caps thread names at 15 bytes
        0 => raddbg.threadName("worker {d} with a name longer than fifteen bytes", .{index}),
        // last name wins
        1 => {
            raddbg.threadName("temporary", .{});
            raddbg.threadName("worker {d} renamed", .{index});
        },
        // windows converts names to utf-16
        2 => raddbg.threadName("wörker {d} ", .{index}),
        // the C version formats into a 512 byte buffer
        3 => {
            const long_text: [5000]u8 = @splat('x');
            raddbg.threadName("worker {d} {s}", .{ index, &long_text });
        },
        else => raddbg.threadName("worker {d}", .{index}),
    }
    raddbg.log("worker {d} (id {d}) named itself", .{ index, raddbg.threadId() });
}

fn colourSelf(index: usize) void {
    // even workers use the u32 palette, odd workers the rgba palette
    if (index % 2 == 0) {
        raddbg.threadColorU32(colours_u32[index]);
    } else {
        const c = colours_rgba[index];
        raddbg.threadColorRgba(c[0], c[1], c[2], c[3]);
    }
    raddbg.log("worker {d} (id {d}) coloured itself", .{ index, raddbg.threadId() });
}
