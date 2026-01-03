const std = @import("std");
const pg = @import("pg");
const queue = @import("queue.zig");

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

pub const TransformedRecord = struct {
    id: i32,
    ref_id: i32,
    balance: i32,
    full_name: []const u8,
    email_domain: []const u8,
    source: []const u8,
    processed_at: []const u8,
};

allocator: std.mem.Allocator,
concurrency: i32,
batch_size: i32,
pg_pool: *pg.Pool,
extract_queue: *queue.Queue(Record),
transform_queue: *queue.Queue(TransformedRecord),
should_stop: std.atomic.Value(bool),

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
        .extract_queue = try queue.Queue(Record).init(allocator),
        .transform_queue = try queue.Queue(TransformedRecord).init(allocator),
        .should_stop = std.atomic.Value(bool).init(false),
    };

    return self;
}

pub fn deinit(self: *Etl) void {
    self.extract_queue.deinit();
    self.transform_queue.deinit();
    self.allocator.destroy(self);
}
