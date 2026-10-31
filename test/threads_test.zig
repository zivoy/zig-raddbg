const std = @import("std");
const raddbg = @import("raddbg");
const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    std.debug.print("debugger is {s}\n", .{if (raddbg.isAttached()) "attached" else "not attached"});

    var gate: Gate = .{};

    // ---

    raddbg.threadName("main", .{});

    const threads = try spawnWorkers(nameSelf, io, &gate);
    gate.waitAll(io);
    checkpoint();
    gate.release(io);
    joinAll(threads);

    // ---
}

fn checkpoint() void {
    raddbg.breakpointIf(raddbg.isAttached());
}

const worker_count = 4;

const Gate = struct {
    ids: [worker_count]std.Thread.Id = undefined,
    ready: [worker_count]Io.Event = @splat(.unset),
    open: Io.Event = .unset,

    fn arrive(gate: *Gate, io: Io, index: usize) void {
        gate.ids[index] = raddbg.threadId();
        gate.ready[index].set(io);
        gate.open.waitUncancelable(io);
    }

    fn waitAll(gate: *Gate, io: Io) void {
        for (&gate.ready) |*event| event.waitUncancelable(io);
    }

    fn release(gate: *Gate, io: Io) void {
        gate.open.set(io);
    }
};

fn spawnWorkers(comptime function: anytype, io: Io, gate: *Gate) ![worker_count]std.Thread {
    var threads: [worker_count]std.Thread = undefined;
    for (&threads, 0..) |*thread, idx| {
        gate.ready[idx].reset();
        thread.* = try std.Thread.spawn(.{}, function, .{ io, gate, idx });
    }
    return threads;
}

fn joinAll(threads: [worker_count]std.Thread) void {
    for (threads) |thread| thread.join();
}

// ---

fn nameSelf(io: Io, gate: *Gate, index: usize) void {
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
    gate.arrive(io, index);
}
