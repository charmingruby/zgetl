const std = @import("std");
const pg = @import("pg");
const date = @import("datetime");
const queue = @import("queue.zig");
const store = @import("store.zig");
const Uid = @import("../UId.zig");

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
    _line_buffer: []const u8,

    fn deinit(self: Record, allocator: std.mem.Allocator) void {
        allocator.free(self._line_buffer);
    }
};

pub const TransformedRecord = struct {
    id: []const u8,
    full_name: []const u8,
    email_domain: []const u8,
    source: []const u8,
    processed_at: []const u8,
    ref_id: i32,
    balance: i32,

    fn deinit(self: TransformedRecord, allocator: std.mem.Allocator) void {
        allocator.free(self.full_name);
        allocator.free(self.email_domain);
        allocator.free(self.processed_at);
    }
};

allocator: std.mem.Allocator,
id_generator: *Uid,
concurrency: i32,
batch_size: i32,
pg_pool: *pg.Pool,
extract_queue: *queue.Queue(Record),
transform_queue: *queue.Queue(TransformedRecord),
should_stop: std.atomic.Value(bool),

pub fn init(
    allocator: std.mem.Allocator,
    pg_pool: *pg.Pool,
    id_gen: *Uid,
    opts: Options,
) !*Etl {
    const self = try allocator.create(Etl);

    self.* = .{
        .allocator = allocator,
        .id_generator = id_gen,
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

        const line_copy = try self.allocator.dupe(u8, line.?);
        errdefer self.allocator.free(line_copy);

        const record = try self.parseCsvLine(line_copy);

        try self.extract_queue.push(record);

        record_count += 1;
    }
}

pub fn transform(self: *Etl, _: usize) !void {
    defer self.transform_queue.close();

    while (true) {
        if (self.should_stop.load(.acquire)) {
            break;
        }

        const record = self.extract_queue.pop() orelse {
            break;
        };

        const full_name = try self.allocator.dupe(u8, record.name);
        errdefer self.allocator.free(full_name);

        const email_domain = try self.allocator.dupe(
            u8,
            self.extractDomainFromEmail(record.email),
        );
        errdefer self.allocator.free(email_domain);

        const balance_in_cents: i32 = @intFromFloat(record.amount * 100);

        const now = date.datetime.Datetime.now();
        const now_f = try now.formatISO8601(self.allocator, false);

        const transformed = TransformedRecord{
            .id = try self.id_generator.generateId(),
            .full_name = full_name,
            .email_domain = email_domain,
            .balance = balance_in_cents,
            .ref_id = record.id,
            .source = "Zig",
            .processed_at = now_f,
        };

        record.deinit(self.allocator);

        try self.transform_queue.push(transformed);
    }
}

pub fn load(self: *Etl) !void {
    var batch = try std.ArrayList(TransformedRecord).initCapacity(self.allocator, 0);

    defer batch.deinit(self.allocator);

    const flush = struct {
        fn process(
            allocator: std.mem.Allocator,
            pool: *pg.Pool,
            t_batch: *std.ArrayList(TransformedRecord),
        ) !void {
            defer {
                for (t_batch.items) |i| {
                    i.deinit(allocator);
                }

                t_batch.clearRetainingCapacity();
            }

            if (t_batch.items.len == 0) return;

            try store.insertBatch(pool, t_batch.*);
        }
    };

    var last_flush = std.time.milliTimestamp();

    while (true) {
        if (self.should_stop.load(.acquire)) {
            break;
        }

        switch (try self.transform_queue.popTimeout(5000 * std.time.ns_per_ms)) {
            .item => |t| try batch.append(self.allocator, t),
            .timeout => {},
            .closed => break,
        }

        const current_time = std.time.milliTimestamp();
        const should_flush_time = (current_time - last_flush) >= 5000; // 5 sec

        if (batch.items.len >= self.batch_size or should_flush_time) {
            try flush.process(self.allocator, self.pg_pool, &batch);
            last_flush = current_time;
        }
    }

    if (batch.items.len > 0) {
        try flush.process(self.allocator, self.pg_pool, &batch);
    }
}

fn extractDomainFromEmail(_: *Etl, email: []const u8) []const u8 {
    var it = std.mem.splitBackwardsSequence(u8, email, "@");

    const domain = it.next() orelse unreachable;

    return domain;
}

fn parseCsvLine(_: *Etl, line: []const u8) !Record {
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
        ._line_buffer = line,
    };
}
