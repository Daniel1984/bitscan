const std = @import("std");
const json = std.json;

pub const ScriptPubKey = struct {
    @"asm": ?[]const u8 = null,
    hex: ?[]const u8 = null,
    address: ?[]const u8 = null,
    type: ?[]const u8 = null,
};

pub const Output = struct {
    value: f64,
    n: u32,
    scriptPubKey: ScriptPubKey,
};

pub const Input = struct {
    // common fields
    sequence: u64,
    txinwitness: ?[]json.Value = null,

    // fields for regular transactions
    txid: ?[]const u8 = null,
    vout: ?u32 = null,
    scriptSig: ?json.Value = null,
    prevout: ?Prevout = null,

    // fields for regular transactions
    coinbase: ?[]const u8 = null,
};

pub const Prevout = struct {
    generated: bool,
    height: u32,
    value: f64,
    scriptPubKey: ScriptPubKey,
};

pub const Transaction = struct {
    txid: []const u8,
    hash: []const u8,
    version: i32,
    size: u32,
    vsize: u32,
    weight: u32,
    locktime: u64,
    vin: []Input,
    vout: []Output,
};

pub const BlockResponse = struct {
    hash: []const u8,
    previousblockhash: []const u8,
    nextblockhash: []const u8,
    merkleroot: []const u8,
    nTx: u32,
    time: u32,
    mediantime: u64,
    height: u32,
    version: u32,
    versionHex: []const u8,
    bits: []const u8,
    difficulty: f64,
    fee: f64,
    chainwork: []const u8,
    strippedsize: u32,
    weight: u32,
    size: u32,
    tx: []Transaction,
};
