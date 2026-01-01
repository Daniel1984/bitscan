const std = @import("std");
const httpz = @import("httpz");
const Env = @import("./env.zig");
const Db = @import("./db.zig").Db;
const App = @import("./app.zig");
const Stream = @import("./stream.zig");
const Backfill = @import("./backfill.zig");
const BlockProcessor = @import("./blockprocessor.zig").BlockProcessor;
const Runtime = @import("./runtime.zig").Runtime;

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

    var zmq_stream = try Stream.init(allocator, .{ .stream_url = zmq_endpoint });
    defer zmq_stream.deinit();

    var backfill = Backfill.init(allocator, .{ .btc_rest_endpoint = btc_rest_endpoint });

    var block_processor = BlockProcessor.init(allocator, .{ .btc_rest_endpoint = btc_rest_endpoint, .db = dbpool });
    defer block_processor.deinit();

    var runtime = try Runtime.init(
        allocator,
        &zmq_stream,
        &backfill,
        &block_processor,
    );
    defer runtime.deinit();

    try runtime.start();
    defer runtime.stop();

    var app = App.init(allocator, dbpool);
    try app.startApi(api_port);
}
