const std = @import("std");

pub const Example = @This();

allocator: std.mem.Allocator,
id: []const u8,

pub fn init(allocator: std.mem.Allocator, id: []const u8) !*Example {
    const self = try allocator.create(Example);

    self.* = .{
        .id = id,
        .allocator = allocator,
    };

    return self;
}

pub fn deinit(self: *Example) void {
    self.allocator.destroy(self);
}

pub fn identify(self: *Example) []const u8 {
    return self.id;
}

test "Example: init and deinit" {
    const testing = std.testing;

    const id: []const u8 = "123";

    const ex = try Example.init(testing.allocator, id);

    ex.deinit();
}

test "Example: gets identity" {
    const testing = std.testing;

    const id: []const u8 = "123";

    const ex = try Example.init(testing.allocator, id);
    defer ex.deinit();

    try testing.expectEqual(id, ex.identify());
}
