const std = @import("std");

pub fn Queue(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        items: std.ArrayList(T),
        mutex: std.Thread.Mutex,
        cond: std.Thread.Condition,
        closed: bool,

        pub fn init(allocator: std.mem.Allocator) !*Self {
            const self = try allocator.create(Self);

            self.* = .{
                .allocator = allocator,
                .items = try std.ArrayList(T).initCapacity(allocator, 0),
                .cond = .{},
                .mutex = .{},
                .closed = false,
            };

            return self;
        }

        pub fn deinit(self: *Self) void {
            self.items.deinit(self.allocator);
            self.allocator.destroy(self);
        }

        pub fn push(self: *Self, item: T) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.closed) return error.QueueClosed;

            try self.items.append(self.allocator, item);
            self.cond.signal();
        }

        pub fn pop(self: *Self) ?T {
            self.mutex.lock();
            defer self.mutex.unlock();

            while (self.items.items.len == 0 and !self.closed) {
                self.cond.wait(&self.mutex);
            }

            if (self.items.items.len == 0) return null;

            return self.items.orderedRemove(0);
        }

        pub fn close(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            self.closed = true;
            self.cond.broadcast();
        }
    };
}
