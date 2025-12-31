const std = @import("std");
const Db = @import("./db.zig").Db;

allocator: std.mem.Allocator,

pub const StreamProcessor = @This();

pub fn init(a: std.mem.Allocator) StreamProcessor {
    return .{
        .allocator = a,
    };
}

pub fn toHex(self: StreamProcessor, msg: []const u8) ![]u8 {
    var hex_string = try self.allocator.alloc(u8, msg.len * 2);
    defer self.allocator.free(hex_string);

    for (msg, 0..) |byte, i| {
        _ = try std.fmt.bufPrint(hex_string[i * 2 .. i * 2 + 2], "{x:0>2}", .{byte});
    }

    return self.allocator.dupe(u8, hex_string);
}
