const std = @import("std");
pub const std_views = @import("std_views.zig");

// ---

const testing = std.testing;

test "yes" {
    try testing.expect(true);
}
