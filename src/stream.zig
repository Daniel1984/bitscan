const std = @import("std");
const zimq = @import("zimq");

const Self = @This();

allocator: std.mem.Allocator,
shouldConsume: bool,
stream_url: [:0]const u8,
context: ?*zimq.Context,

pub const Opts = struct {
    stream_url: []const u8 = "tcp://127.0.0.1:28444",
};

pub fn init(allocator: std.mem.Allocator, opts: Opts) !Self {
    return Self{
        .allocator = allocator,
        .stream_url = try allocator.dupeZ(u8, opts.stream_url),
        .shouldConsume = true,
        .context = null,
    };
}

pub fn deinit(self: *Self) void {
    self.shouldConsume = false;
    self.allocator.free(self.stream_url);
    self.deinitStream();
}

fn deinitStream(self: *Self) void {
    if (self.context) |ctx| {
        ctx.deinit();
        self.context = null;
    }
}

fn connectSocket(self: *Self) !*zimq.Socket {
    self.deinitStream();
    std.debug.print("[ZMQ] connecting to {s}\n", .{self.stream_url});

    self.context = try zimq.Context.init();
    const socket = try zimq.Socket.init(self.context.?, .sub);

    // subscribe to ALL topics ("")
    try socket.set(.subscribe, "");
    // or be explicit
    // try socket.set(.subscribe, "rawblock");
    // try socket.set(.subscribe, "rawtx");

    try socket.connect(self.stream_url);
    std.debug.print("[ZMQ] connected\n", .{});
    return socket;
}

pub fn consume(self: *Self, cb: fn ([]const u8, []const u8) void) !void {
    var topic = zimq.Message.empty();
    var payload = zimq.Message.empty();
    var seq = zimq.Message.empty();

    while (self.shouldConsume) {
        const stream = self.connectSocket() catch |err| {
            std.debug.print("connection failed: {}, retrying in 5 seconds...\n", .{err});
            std.Thread.sleep(5 * std.time.ns_per_s);
            continue;
        };
        defer stream.deinit();

        while (self.shouldConsume) {
            _ = stream.recvMsg(&topic, .{}) catch |err| {
                std.debug.print("failed to receive topic from stream: {}\n", .{err});
                continue;
            };
            _ = stream.recvMsg(&payload, .{}) catch |err| {
                std.debug.print("failed to receive payload from stream: {}\n", .{err});
                continue;
            };
            _ = stream.recvMsg(&seq, .{}) catch |err| {
                std.debug.print("failed to receive sequence from stream: {}\n", .{err});
                continue;
            };

            const topic_str = topic.slice();
            const data = payload.slice();
            cb(topic_str, data);
        }

        std.debug.print("reconnecting in 2 seconds...\n", .{});
        std.Thread.sleep(2 * std.time.ns_per_s);
    }
}
