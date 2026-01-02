const std = @import("std");
const Example = @import("Example.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const ex = try Example.init(allocator, "id-123");
    defer ex.deinit();

    std.log.info("ex id={s}", .{ex.id});
}
