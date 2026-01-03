const std = @import("std");
const pg = @import("pg");

pub const Etl = @This();

const DEFAULT_BATCH_SIZE = 100;
const DEFAULT_CONCURRENCY = 16;

pub const Options = struct {
    concurrency: ?i32,
    batch_size: ?i32,
};

pub const Record = struct {
    name: []const u8,
    email: []const u8,
    created_at: []const u8,
    amount: f64,
    id: i32,
};

allocator: std.mem.Allocator,
concurrency: i32,
batch_size: i32,
pg_pool: *pg.Pool,

pub fn init(
    allocator: std.mem.Allocator,
    pg_pool: *pg.Pool,
    opts: Options,
) !*Etl {
    const self = try allocator.create(Etl);

    self.* = .{
        .allocator = allocator,
        .pg_pool = pg_pool,
        .batch_size = opts.batch_size orelse DEFAULT_BATCH_SIZE,
        .concurrency = opts.batch_size orelse DEFAULT_CONCURRENCY,
    };

    return self;
}

pub fn deinit(self: *Etl) void {
    self.allocator.destroy(self);
}
