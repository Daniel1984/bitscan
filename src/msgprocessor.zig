const std = @import("std");
const Db = @import("./db.zig").Db;
const Stream = @import("./stream.zig");

allocator: std.mem.Allocator,
db: *Db,

pub const MsgProcessor = @This();

pub fn init(a: std.mem.Allocator, d: *Db) MsgProcessor {
    return .{
        .allocator = a,
        .db = d,
    };
}

pub fn deinit(_: *MsgProcessor) void {}

pub fn processMsg(self: MsgProcessor, topic: []const u8, msg: []const u8) void {
    if (!std.mem.eql(u8, topic, "hashblock") and !std.mem.eql(u8, topic, "hashtx")) return;
    std.debug.print("[ZMQ] topic={s} size={}\n", .{ topic, msg.len });

    var hex_string = self.allocator.alloc(u8, msg.len * 2) catch return;
    defer self.allocator.free(hex_string);

    for (msg, 0..) |byte, i| {
        _ = std.fmt.bufPrint(hex_string[i * 2 .. i * 2 + 2], "{x:0>2}", .{byte}) catch return;
    }

    std.debug.print("[ZMQ] hex: {s}\n", .{hex_string});
    self.print(hex_string);
}

fn print(_: MsgProcessor, hex_string: []const u8) void {
    std.debug.print("[ZMQ] print hex: {s}\n", .{hex_string});
}
