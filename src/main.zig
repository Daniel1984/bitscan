const std = @import("std");
const httpz = @import("httpz");
const Env = @import("./env.zig");
const Db = @import("./db.zig").Db;
const App = @import("./app.zig");
const handlers = @import("./handlers/handlers.zig");
const Stream = @import("./stream.zig");
const StreamProcessor = @import("./streamprocessor.zig");
const Backfill = @import("./backfill.zig");

var msg_processor: StreamProcessor = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        std.debug.panic("leaks detected", .{});
    };
    const allocator = gpa.allocator();

    var env = Env.init(allocator);
    const api_port: u16 = env.getInt(u16, "PORT", 5888);
    const zmq_endpoint = env.getString("ZMQ_ENDPOINT", "tcp://127.0.0.1:28333");
    defer allocator.free(zmq_endpoint);
    const btc_rest_endpoint = env.getString("BTC_REST_ENDPOINT", "http://127.0.0.1:38332/rest");
    defer allocator.free(btc_rest_endpoint);

    const dbpool = try Db.init(allocator);
    defer dbpool.deinit();
    try dbpool.ping();

    var app = App.init(dbpool, allocator);

    var server = try httpz.Server(*App).init(allocator, .{ .port = api_port, .address = "0.0.0.0" }, &app);
    defer server.deinit();
    defer server.stop();

    var router = try server.router(.{});
    router.get("/status", handlers.getStatus, .{});

    var zmq_stream = try Stream.init(allocator, .{ .stream_url = zmq_endpoint });
    defer zmq_stream.deinit();

    msg_processor = StreamProcessor.init(allocator, dbpool, btc_rest_endpoint);
    const stream_thread = try std.Thread.spawn(.{}, consumeStream, .{&zmq_stream});
    defer stream_thread.join();

    const backfill = Backfill.init(allocator, .{
        .btc_rest_endpoint = btc_rest_endpoint,
        .from_block = 0,
        .to_block = 10,
    });

    const hash = try backfill.getBlockHash(0);
    std.log.info("Block hash for height: {s}", .{hash});

    std.log.info("server started at port: {d}", .{api_port});
    try server.listen();
}

fn handleMessageWrapper(topic: []const u8, msg: []const u8) void {
    msg_processor.processMsg(topic, msg);
}

fn consumeStream(s: *Stream) void {
    s.consume(handleMessageWrapper);
}
