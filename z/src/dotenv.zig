const std = @import("std");

pub const ConfigError = error{
    MissingEnvVar,
    InvalidFormat,
};

var env_map: std.StringHashMap([]const u8) = undefined;
var env_loaded = false;
var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};

pub fn load() void {
    if (env_loaded) return;

    const allocator = gpa.allocator();
    env_map = std.StringHashMap([]const u8).init(allocator);

    const file = std.fs.cwd().openFile(".env", .{}) catch {
        env_loaded = true;
        return;
    };
    defer file.close();

    const content = file.readToEndAlloc(allocator, 1024 * 1024) catch {
        env_loaded = true;
        return;
    };

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        if (std.mem.indexOfScalar(u8, trimmed, '=')) |idx| {
            const key = allocator.dupe(u8, std.mem.trim(u8, trimmed[0..idx], &std.ascii.whitespace)) catch continue;
            const value = allocator.dupe(u8, std.mem.trim(u8, trimmed[idx + 1 ..], &std.ascii.whitespace)) catch continue;
            env_map.put(key, value) catch continue;
        }
    }

    env_loaded = true;
}

pub fn get(comptime T: type, name: []const u8) !T {
    const value = env_map.get(name) orelse std.posix.getenv(name) orelse return ConfigError.MissingEnvVar;

    return switch (@typeInfo(T)) {
        .bool => parseBool(value) catch return ConfigError.InvalidFormat,
        .float => std.fmt.parseFloat(T, value) catch return ConfigError.InvalidFormat,
        .int => std.fmt.parseInt(T, value, 10) catch return ConfigError.InvalidFormat,
        .pointer => |ptr| blk: {
            if (ptr.child == u8 and ptr.size == .slice) {
                break :blk value;
            }

            @compileError("unsupported pointer type");
        },
        else => @compileError("unsupported type: " ++ @typeName(T)),
    };
}

pub fn getOrDefault(comptime T: type, name: []const u8, default: T) T {
    return get(T, name) catch default;
}

pub fn getOptional(comptime T: type, name: []const u8) ?T {
    return get(T, name) catch undefined;
}

fn parseBool(value: []const u8) !bool {
    if (std.mem.eql(u8, value, "true")) {
        return true;
    } else if (std.mem.eql(u8, value, "false")) {
        return false;
    }

    return error.InvalidFormat;
}
