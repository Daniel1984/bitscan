const std = @import("std");
const Db = @import("./db.zig").Db;

allocator: std.mem.Allocator,

pub const StreamProcessor = @This();

pub fn init(a: std.mem.Allocator) StreamProcessor {
    return .{
        .allocator = a,
    };
}

pub fn processMsg(self: StreamProcessor, topic: []const u8, msg: []const u8) ![]u8 {
    std.debug.print("[ZMQ] topic={s} size={}\n", .{ topic, msg.len });

    var hex_string = try self.allocator.alloc(u8, msg.len * 2);
    defer self.allocator.free(hex_string);

    for (msg, 0..) |byte, i| {
        _ = try std.fmt.bufPrint(hex_string[i * 2 .. i * 2 + 2], "{x:0>2}", .{byte});
    }

    std.debug.print("[ZMQ] block hash hex: {s}\n", .{hex_string});
    return self.allocator.dupe(u8, hex_string);
}
