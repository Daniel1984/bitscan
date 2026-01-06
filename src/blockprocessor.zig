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

        // below 5LOC just for debugging
        // var out: std.io.Writer.Allocating = .init(self.allocator);
        // try std.json.Stringify.value(block, .{ .whitespace = .indent_2 }, &out.writer);
        // var arr = out.toArrayList();
        // defer arr.deinit(self.allocator);
        // std.debug.print("Block: {s}\n", .{arr.items});

        const conn = try self.db.pool.acquire();
        defer self.db.pool.release(conn);

        try conn.begin();
        errdefer {
            conn.rollback() catch |err| {
                std.debug.print("failed to rollback transaction: {}\n", .{err});
            };
        }

        // std.log.info("injesting block: {s} | height {d} | txs {d}", .{ block.hash, block.height, block.nTx });
        const block_result = try conn.query(
            \\INSERT INTO blocks (
            \\  height, hash, chainwork, version, version_hex, bits, difficulty,
            \\  time, mediantime, stripped_size, size, weight, tx_count
            \\) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
            \\RETURNING id
        , .{ block.height, block.hash, block.chainwork, block.version, block.versionHex, block.bits, block.difficulty, block.time, block.mediantime, block.strippedsize, block.size, block.weight, block.nTx });
        defer block_result.deinit();

        var block_id: ?i64 = null;
        if (try block_result.next()) |row| {
            block_id = row.get(i64, 0);
        }

        // drain the result to avoid ConnectionBusy error
        try block_result.drain();
        const db_block_id = block_id orelse return error.BlockInsertFailed;

        for (block.tx, 0..) |tx, tx_idx| {
            const tx_result = try conn.query(
                \\INSERT INTO transactions (
                \\  block_id, txid, tx_index, version, size, vsize,
                \\  weight, locktime, is_coinbase, fee
                \\) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
                \\RETURNING id
            , .{
                db_block_id,
                tx.txid,
                @as(i32, @intCast(tx_idx)),
                tx.version,
                tx.size,
                tx.vsize,
                tx.weight,
                tx.locktime,
                tx.vin.len > 0 and tx.vin[0].coinbase != null,
                @as(i64, @intFromFloat(tx.fee * 100_000_000)),
            });
            defer tx_result.deinit();

            var transaction_id: ?i64 = null;
            if (try tx_result.next()) |row| {
                transaction_id = row.get(i64, 0);
            }

            const db_tx_id = transaction_id orelse return error.TransactionInsertFailed;
            // drain the result to avoid ConnectionBusy error
            try tx_result.drain();

            for (tx.vout) |output| {
                _ = try conn.exec(
                    \\INSERT INTO outputs (
                    \\  transaction_id, txid, vout, value, script_pubkey_hex,
                    \\  script_type, address
                    \\) VALUES ($1, $2, $3, $4, $5, $6, $7)
                , .{
                    db_tx_id,
                    tx.txid,
                    output.n,
                    @as(i64, @intFromFloat(output.value * 100_000_000)),
                    output.scriptPubKey.hex,
                    output.scriptPubKey.type,
                    output.scriptPubKey.address,
                });
            }

            for (tx.vin, 0..) |input, vin_idx| {
                _ = try conn.exec(
                    \\INSERT INTO inputs (
                    \\  transaction_id, vin, txid,
                    \\  vout, sequence, is_coinbase
                    \\) VALUES ($1, $2, $3, $4, $5, $6)
                , .{
                    db_tx_id,
                    @as(i32, @intCast(vin_idx)),
                    if (input.coinbase) |_| null else input.txid,
                    if (input.coinbase) |_| null else input.vout,
                    input.sequence,
                    if (input.coinbase) |_| true else false,
                });
            }
        }

        try conn.commit();
        std.log.info("✅ block: {s} | height {d} | txs {d}", .{ block.hash, block.height, block.nTx });
    }
};
