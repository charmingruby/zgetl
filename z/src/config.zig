const std = @import("std");
const dotenv = @import("dotenv.zig");

pub const Config = @This();

allocator: std.mem.Allocator,
batch_size: i32,
concurrency: i32,
database_port: i32,
database_host: []const u8,
database_name: []const u8,
database_username: []const u8,
database_password: []const u8,

pub fn init(allocator: std.mem.Allocator) !*Config {
    const self = try allocator.create(Config);
    errdefer allocator.destroy(self);

    self.* = .{
        .allocator = allocator,
        .batch_size = dotenv.getOrDefault(i32, "BATCH_SIZE", 100),
        .concurrency = dotenv.getOrDefault(i32, "CONCURRENCY", 10),
        .database_host = try dotenv.get([]const u8, "DATABASE_HOST"),
        .database_port = try dotenv.get(i32, "DATABASE_PORT"),
        .database_name = try dotenv.get([]const u8, "DATABASE_NAME"),
        .database_username = try dotenv.get([]const u8, "DATABASE_USERNAME"),
        .database_password = try dotenv.get([]const u8, "DATABASE_PASSWORD"),
    };

    return self;
}

pub fn deinit(self: *Config) void {
    self.allocator.destroy(self);
}
