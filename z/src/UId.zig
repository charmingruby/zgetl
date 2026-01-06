const std = @import("std");
const uuid = @import("uuid");

pub const UId = @This();

allocator: std.mem.Allocator,
ids: std.ArrayList([]const u8),
mutex: std.Thread.Mutex,

pub fn init(allocator: std.mem.Allocator) !*UId {
    const self = try allocator.create(UId);

    self.* = .{
        .allocator = allocator,
        .ids = try std.ArrayList([]const u8).initCapacity(allocator, 0),
        .mutex = .{},
    };

    return self;
}

pub fn generateId(self: *UId) ![]const u8 {
    self.mutex.lock();
    defer self.mutex.unlock();

    const id = uuid.v7.new();

    const id_str = std.fmt.allocPrint(self.allocator, "{d}", .{id}) catch unreachable;

    try self.ids.append(self.allocator, id_str);

    return id_str;
}

pub fn deinit(self: *UId) void {
    for (self.ids.items) |id| {
        self.allocator.free(id);
    }

    self.ids.deinit(self.allocator);

    self.allocator.destroy(self);
}
