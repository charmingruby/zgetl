const std = @import("std");
const Etl = @import("Etl.zig");
const pg = @import("pg");

pub fn insertBatch(pg_pool: *pg.Pool, records: std.ArrayList(Etl.TransformedRecord)) !void {
    const conn = try pg_pool.acquire();
    defer pg_pool.release(conn);

    _ = try conn.exec("BEGIN", .{});

    errdefer _ = conn.exec("ROLLBACK", .{}) catch |err| {
        std.log.err("rollback failure: {any}", .{err});
    };

    for (records.items) |r| {
        _ = try conn.exec(
            \\INSERT INTO processed_records (id, fullname, email_domain, source, ref_id, balance, processed_at)
            \\VALUES ($1, $2, $3, $4, $5, $6, $7)
        , .{
            r.id,
            r.full_name,
            r.email_domain,
            r.source,
            r.ref_id,
            r.balance,
            r.processed_at,
        });
    }

    _ = try conn.exec("COMMIT", .{});
}
