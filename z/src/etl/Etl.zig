const std = @import("std");
const pg = @import("pg");
const queue = @import("queue.zig");
const store = @import("store.zig");

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

pub fn extract(self: *Etl, filepath: []const u8) !void {
    defer self.extract_queue.close();

    const file = try std.fs.cwd().openFile(filepath, .{});
    defer file.close();

    var buf: [8192]u8 = undefined;
    const reader = file.deprecatedReader();

    var record_count: usize = 0;

    _ = try reader.readUntilDelimiterOrEof(&buf, '\n');

    while (true) {
        if (self.should_stop.load(.acquire)) {
            break;
        }

        const line = reader.readUntilDelimiterOrEof(&buf, '\n') catch |err| {
            if (err == error.EndOfStream) break;

            return err;
        };

        if (line == null) break;

        const record = try self.parseCsvLine(line.?);

        try self.extract_queue.push(record);

        record_count += 1;
    }
}

pub fn parseCsvLine(_: *Etl, line: []const u8) !Record {
    var it = std.mem.splitScalar(u8, line, ',');

    const id_str = it.next() orelse return error.InvalidCsv;
    const name = it.next() orelse return error.InvalidCsv;
    const email = it.next() orelse return error.InvalidCsv;
    const amount_str = it.next() orelse return error.InvalidCsv;
    const created_at_str = it.next() orelse return error.InvalidCsv;

    const id = try std.fmt.parseInt(i32, id_str, 10);
    const amount = try std.fmt.parseFloat(f32, amount_str);

    return Record{
        .id = id,
        .name = name,
        .email = email,
        .amount = amount,
        .created_at = created_at_str,
    };
}
