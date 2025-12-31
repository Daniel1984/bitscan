const std = @import("std");
const Stream = @import("./stream.zig");
const StreamProcessor = @import("./streamprocessor.zig");
const Backfill = @import("./backfill.zig");
const BlockProcessor = @import("./blockprocessor.zig").BlockProcessor;
const Fifo = @import("./fifo.zig").Fifo;

pub const BlockJob = struct {
    hash: []const u8,
    source: enum { zmq, backfill },
};

pub const Runtime = struct {
    allocator: std.mem.Allocator,

    stream: *Stream,
    stream_processor: *StreamProcessor,
    backfill: *Backfill,
    block_processor: *BlockProcessor,

    fifo: Fifo(BlockJob),

    zmq_thread: ?std.Thread = null,
    backfill_thread: ?std.Thread = null,
    consumer_thread: ?std.Thread = null,

    pub fn init(
        allocator: std.mem.Allocator,
        stream: *Stream,
        stream_processor: *StreamProcessor,
        backfill: *Backfill,
        block_processor: *BlockProcessor,
    ) Runtime {
        return .{
            .allocator = allocator,
            .stream = stream,
            .stream_processor = stream_processor,
            .backfill = backfill,
            .block_processor = block_processor,
            .fifo = Fifo(BlockJob).init(allocator),
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
            const msg = self.stream.next() catch continue;

            if (!std.mem.eql(u8, msg.topic, "hashblock")) continue;

            const hash = self.stream_processor.toHex(msg.payload) catch continue;

            self.fifo.send(.{
                .hash = hash,
                .source = .zmq,
            }) catch {};
        }
    }

    fn backfillLoop(self: *Runtime) void {
        var h: u32 = 0;
        while (h <= 10) : (h += 1) {
            const hash = self.backfill.getBlockHash(h) catch continue;

            self.fifo.send(.{
                .hash = hash,
                .source = .backfill,
            }) catch {};

            std.Thread.sleep(1000 * std.time.ns_per_ms);
        }
    }

    fn consumerLoop(self: *Runtime) void {
        while (true) {
            const job = self.fifo.receive();
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
