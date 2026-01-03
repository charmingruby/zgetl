const std = @import("std");
const Example = @import("Example.zig");
const config = @import("config.zig");
const dotenv = @import("dotenv.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    dotenv.load();

    const conf = try config.init(allocator);
    defer conf.deinit();
}
