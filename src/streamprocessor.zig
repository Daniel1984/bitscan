const std = @import("std");
const Db = @import("./db.zig").Db;
const Stream = @import("./stream.zig");
const request = @import("./request.zig");
const BlockResponse = @import("./models/block.zig").BlockResponse;

const json = std.json;

allocator: std.mem.Allocator,
btc_rest_endpoint: []const u8,
db: *Db,

pub const StreamProcessor = @This();

pub fn init(a: std.mem.Allocator, d: *Db, b: []const u8) StreamProcessor {
    return .{
        .allocator = a,
        .db = d,
        .btc_rest_endpoint = b,
    };
}

pub fn processMsg(self: StreamProcessor, topic: []const u8, msg: []const u8) void {
    if (!std.mem.eql(u8, topic, "hashblock")) return;
    std.debug.print("[ZMQ] topic={s} size={}\n", .{ topic, msg.len });

    var hex_string = self.allocator.alloc(u8, msg.len * 2) catch return;
    defer self.allocator.free(hex_string);

    for (msg, 0..) |byte, i| {
        _ = std.fmt.bufPrint(hex_string[i * 2 .. i * 2 + 2], "{x:0>2}", .{byte}) catch return;
    }

    std.debug.print("[ZMQ] block hash hex: {s}\n", .{hex_string});

    self.fetchBlock(hex_string) catch |err| {
        std.debug.print("Error fetching transaction: {}\n", .{err});
    };
}

fn fetchBlock(self: StreamProcessor, tx_hash: []const u8) !void {
    var url_buf: [128]u8 = undefined;
    const url_str = try std.fmt.bufPrint(&url_buf, "{s}/block/{s}.json", .{ self.btc_rest_endpoint, tx_hash });
    const body = try request.get(self.allocator, url_str);
    defer self.allocator.free(body);

    var parsed = try json.parseFromSlice(BlockResponse, self.allocator, body, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
        .duplicate_field_behavior = .use_first, // Handle duplicate fields if any
    });
    defer parsed.deinit();

    const block = parsed.value;
    for (block.tx) |tx| {
        std.debug.print("txid: {s} with {d} inputs and {d} outputs\n", .{ tx.txid, tx.vin.len, tx.vout.len });

        for (tx.vin, 0..) |input, i| {
            if (input.coinbase) |coinbase| {
                std.debug.print("  Input {d}: Coinbase - {s}\n", .{ i, coinbase });
            } else if (input.txid) |txid| {
                std.debug.print("  Input {d}: Spends {s}:{d}\n", .{ i, txid, input.vout orelse 0 });
            }
        }
    }
}
