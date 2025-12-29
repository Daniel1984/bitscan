const std = @import("std");
const request = @import("./request.zig");
const json = std.json;

const BlockHash = struct {
    blockhash: []const u8,
};

allocator: std.mem.Allocator,
from_block: u64,
to_block: u64,
btc_rest_endpoint: []const u8,

pub const Backfill = @This();

pub const Options = struct {
    from_block: u64 = 0,
    to_block: u64 = 10,
    btc_rest_endpoint: []const u8,
};

pub fn init(a: std.mem.Allocator, opt: Options) Backfill {
    return .{
        .allocator = a,
        .from_block = opt.from_block,
        .to_block = opt.to_block,
        .btc_rest_endpoint = opt.btc_rest_endpoint,
    };
}

pub fn getBlockHash(self: Backfill, height: u64) ![]const u8 {
    var url_buf: [128]u8 = undefined;
    const url_str = try std.fmt.bufPrint(&url_buf, "{s}/blockhashbyheight/{d}.json", .{ self.btc_rest_endpoint, height });
    const body = try request.get(self.allocator, url_str);
    defer self.allocator.free(body);

    var parsed = try json.parseFromSlice(BlockHash, self.allocator, body, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
    defer parsed.deinit();

    return try self.allocator.dupe(u8, parsed.value.blockhash);
}
