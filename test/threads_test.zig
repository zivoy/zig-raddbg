const std = @import("std");
const raddbg = @import("raddbg");

pub fn main(init: std.process.Init) !void {
    _ = init;

    std.debug.print("debugger is {s}\n", .{if (raddbg.isAttached()) "attached" else "not attached"});
}
