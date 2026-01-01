const std = @import("std");
const Stream = @import("./stream.zig");
const Backfill = @import("./backfill.zig");
const BlockProcessor = @import("./blockprocessor.zig").BlockProcessor;
const MsgQueue = @import("./msgqueue.zig").MsgQueue;

pub const BlockJob = struct {
    hash: []const u8,
    source: enum { zmq, backfill },
};

pub const Runtime = struct {
    allocator: std.mem.Allocator,
    stream: *Stream,
    backfill: *Backfill,
    block_processor: *BlockProcessor,
    msg_queue: MsgQueue(BlockJob),
    zmq_thread: ?std.Thread = null,
    backfill_thread: ?std.Thread = null,
    consumer_thread: ?std.Thread = null,

    pub fn init(
        allocator: std.mem.Allocator,
        stream: *Stream,
        backfill: *Backfill,
        block_processor: *BlockProcessor,
    ) !Runtime {
        return .{
            .allocator = allocator,
            .stream = stream,
            .backfill = backfill,
            .block_processor = block_processor,
            .msg_queue = try MsgQueue(BlockJob).init(allocator),
        };
    }

    pub fn deinit(_: *Runtime) void {}

    pub fn start(self: *Runtime) !void {
        self.zmq_thread = try std.Thread.spawn(.{}, zmqThread, .{self});
        self.backfill_thread = try std.Thread.spawn(.{}, backfillThread, .{self});
        self.consumer_thread = try std.Thread.spawn(.{}, consumerThread, .{self});
    }

    pub fn stop(self: *Runtime) void {
        if (self.zmq_thread) |t| t.join();
        if (self.backfill_thread) |t| t.join();
        if (self.consumer_thread) |t| t.join();
    }

    fn zmqLoop(self: *Runtime) void {
        while (true) {
            const msg = self.stream.next() catch {
                // pause to avoid busy-waiting on connection errors
                std.Thread.sleep(1000 * std.time.ns_per_ms);
                continue;
            };

            defer {
                self.allocator.free(msg.topic);
                self.allocator.free(msg.payload);
            }

            if (!std.mem.eql(u8, msg.topic, "hashblock")) continue;

            const hash = self.stream.toHex(msg.payload) catch continue;

            self.msg_queue.send(.{
                .hash = hash,
                .source = .zmq,
            }) catch {
                self.allocator.free(hash);
            };
        }
    }

    fn backfillLoop(self: *Runtime) void {
        var h: u32 = 285190;
        while (h <= 285193) : (h += 1) {
            const hash = self.backfill.getBlockHash(h) catch continue;

            self.msg_queue.send(.{
                .hash = hash,
                .source = .backfill,
            }) catch {};

            std.Thread.sleep(100 * std.time.ns_per_ms);
        }
    }

    fn consumerLoop(self: *Runtime) void {
        while (true) {
            const job = self.msg_queue.receive() orelse continue;
            defer self.allocator.free(job.hash);

            self.block_processor.process(job.hash) catch |err| {
                std.log.err("failed to process block {s}: {}", .{ job.hash, err });
            };
        }
    }
};

fn zmqThread(rt: *Runtime) void {
    rt.zmqLoop();
}

fn backfillThread(rt: *Runtime) void {
    rt.backfillLoop();
}

fn consumerThread(rt: *Runtime) void {
    rt.consumerLoop();
}
