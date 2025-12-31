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
context: ?*zimq.Context,

pub const Opts = struct {
    stream_url: []const u8 = "tcp://127.0.0.1:28444",
};

pub fn init(allocator: std.mem.Allocator, opts: Opts) !Self {
    return .{
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
    std.debug.print("[ZMQ] connecting to {s}\n", .{self.stream_url});

    self.context = try zimq.Context.init();
    const socket = try zimq.Socket.init(self.context.?, .sub);

    // subscribe to ALL topics ("")
    // try socket.set(.subscribe, "");
    // or be explicit
    // try socket.set(.subscribe, "rawblock");
    // try socket.set(.subscribe, "rawtx");
    try socket.set(.subscribe, "hashblock");

    try socket.connect(self.stream_url);
    std.debug.print("[ZMQ] connected\n", .{});
    return socket;
}

pub fn next(self: *Self) !Message {
    var topic = zimq.Message.empty();
    var payload = zimq.Message.empty();
    var seq = zimq.Message.empty();

    while (self.shouldConsume) {
        const socket = self.connectSocket() catch {
            std.Thread.sleep(2 * std.time.ns_per_s);
            continue;
        };
        defer socket.deinit();

        _ = socket.recvMsg(&topic, .{}) catch {
            self.deinitStream();
            continue;
        };
        _ = socket.recvMsg(&payload, .{}) catch {
            self.deinitStream();
            continue;
        };
        _ = socket.recvMsg(&seq, .{}) catch {
            self.deinitStream();
            continue;
        };

        return .{
            .topic = topic.slice(),
            .payload = payload.slice(),
        };
    }

    return error.StreamClosed;
}
