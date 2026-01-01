const std = @import("std");
const zimq = @import("zimq");

pub const Message = struct {
    topic: []const u8,
    payload: []const u8,
};

const Self = @This();

allocator: std.mem.Allocator,
shouldConsume: bool,
stream_url: [:0]const u8,
context: ?*zimq.Context = null,
socket: ?*zimq.Socket = null,

pub const Opts = struct {
    stream_url: []const u8 = "tcp://127.0.0.1:28444",
};

pub fn init(allocator: std.mem.Allocator, opts: Opts) !Self {
    return .{
        .allocator = allocator,
        .stream_url = try allocator.dupeZ(u8, opts.stream_url),
        .shouldConsume = true,
    };
}

pub fn deinit(self: *Self) void {
    self.shouldConsume = false;
    self.allocator.free(self.stream_url);
    self.deinitStream();
}

fn deinitStream(self: *Self) void {
    if (self.socket) |sock| {
        sock.deinit();
        self.socket = null;
    }

    if (self.context) |ctx| {
        ctx.deinit();
        self.context = null;
    }
}

fn connectSocket(self: *Self) !void {
    self.deinitStream();

    self.context = try zimq.Context.init();
    const socket = try zimq.Socket.init(self.context.?, .sub);
    self.socket = socket;

    // subscribe to ALL topics ("")
    // try socket.set(.subscribe, "");
    // or be explicit
    // try socket.set(.subscribe, "rawblock");
    // try socket.set(.subscribe, "rawtx");
    try socket.set(.subscribe, "hashblock");

    try socket.connect(self.stream_url);
    std.debug.print("[ZMQ] connected to {s}\n", .{self.stream_url});
}

pub fn next(self: *Self) !Message {
    if (self.socket == null) {
        self.connectSocket() catch {
            std.Thread.sleep(2 * std.time.ns_per_s);
            return error.StreamClosed;
        };
    }

    var topic_msg = zimq.Message.empty();
    var payload_msg = zimq.Message.empty();
    var seq_msg = zimq.Message.empty();

    defer topic_msg.deinit();
    defer payload_msg.deinit();
    defer seq_msg.deinit();

    _ = try self.socket.?.recvMsg(&topic_msg, .{});
    _ = try self.socket.?.recvMsg(&payload_msg, .{});
    _ = try self.socket.?.recvMsg(&seq_msg, .{});

    return .{ // caller is the owner
        .topic = try self.allocator.dupe(u8, topic_msg.slice()),
        .payload = try self.allocator.dupe(u8, payload_msg.slice()),
    };
}

pub fn toHex(self: Self, msg: []const u8) ![]u8 {
    const hex_string = try self.allocator.alloc(u8, msg.len * 2);
    errdefer self.allocator.free(hex_string);

    for (msg, 0..) |byte, i| {
        _ = try std.fmt.bufPrint(hex_string[i * 2 .. i * 2 + 2], "{x:0>2}", .{byte});
    }

    return hex_string; // caller is the owner
}
