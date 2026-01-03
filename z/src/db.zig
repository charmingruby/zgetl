const std = @import("std");
const pg = @import("pg");

pub const ConnectionInput = struct {
    port: i32,
    host: []const u8,
    database: []const u8,
    username: []const u8,
    password: []const u8,
};

pub fn connect(allocator: std.mem.Allocator, input: ConnectionInput) !*pg.Pool {
    return try pg.Pool.init(allocator, .{
        .size = 5,
        .connect = .{
            .port = @intCast(input.port),
            .host = input.host,
        },
        .auth = .{
            .username = input.username,
            .password = input.password,
            .database = input.database,
            .timeout = 10_000,
        },
    });
}
