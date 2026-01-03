const std = @import("std");
const config = @import("config.zig");
const dotenv = @import("dotenv.zig");
const db = @import("db.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    dotenv.load();

    const conf = try config.init(allocator);
    defer conf.deinit();

    const pg_pool = try db.connect(allocator, .{
        .database = conf.database_name,
        .host = conf.database_host,
        .port = conf.database_port,
        .username = conf.database_username,
        .password = conf.database_password,
    });
    defer pg_pool.deinit();
}
