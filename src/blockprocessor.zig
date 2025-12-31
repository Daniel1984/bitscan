const std = @import("std");
const request = @import("./request.zig");
const Db = @import("./db.zig").Db;
const BlockResponse = @import("./models/block.zig").BlockResponse;

const json = std.json;

pub const Opts = struct {
    db: *Db,
    btc_rest_endpoint: []const u8,
};

pub const BlockProcessor = struct {
    allocator: std.mem.Allocator,
    btc_rest_endpoint: []const u8,
    db: *Db,

    pub fn init(allocator: std.mem.Allocator, opts: Opts) BlockProcessor {
        return .{ .allocator = allocator, .btc_rest_endpoint = opts.btc_rest_endpoint, .db = opts.db };
    }

    pub fn deinit(self: BlockProcessor) void {
        self.allocator.free(self.btc_rest_endpoint);
    }

    pub fn process(self: BlockProcessor, block_hash: []const u8) !void {
        var url_buf: [128]u8 = undefined;
        const url_str = try std.fmt.bufPrint(&url_buf, "{s}/block/{s}.json", .{ self.btc_rest_endpoint, block_hash });
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
                std.debug.print("Input {d}:\n", .{i});
                if (input.coinbase) |coinbase| {
                    std.debug.print("\tCoinbase - {s}\n", .{coinbase});
                } else if (input.txid) |txid| {
                    std.debug.print("\tSpends {s}:{d}\n", .{ txid, input.vout orelse 0 });
                }
            }

            for (tx.vout, 0..) |output, i| {
                std.debug.print("Output {d}:\n", .{i});
                std.debug.print("\tValue {d}\n", .{output.value});
                if (output.scriptPubKey.address) |address| {
                    std.debug.print("\tAddress {s}\n", .{address});
                }
            }
        }
    }
};
