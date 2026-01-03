const std = @import("std");
const dotenv = @import("dotenv.zig");

pub const Config = @This();

allocator: std.mem.Allocator,
batch_size: i32,
concurrency: i32,
database_url: []const u8,

pub fn init(allocator: std.mem.Allocator) !*Config {
    const self = try allocator.create(Config);
    errdefer allocator.destroy(self);

    self.* = .{
        .allocator = allocator,
        .batch_size = dotenv.getOrDefault(i32, "BATCH_SIZE", 100),
        .concurrency = dotenv.getOrDefault(i32, "CONCURRENCY", 10),
        .database_url = try dotenv.get([]const u8, "DATABASE_URL"),
    };

    return self;
}

pub fn deinit(self: *Config) void {
    self.allocator.destroy(self);
}
