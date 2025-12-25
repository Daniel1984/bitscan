const std = @import("std");
const httpz = @import("httpz");
const Env = @import("./env.zig");
const Db = @import("./db.zig").Db;
const App = @import("./app.zig");
const handlers = @import("./handlers/handlers.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        std.debug.panic("leaks detected", .{});
    };
    const allocator = gpa.allocator();

    var env = Env.init(allocator);
    const port: u16 = env.getInt(u16, "PORT", 5888);

    const dbpool = try Db.init(allocator);
    defer dbpool.deinit();
    try dbpool.ping();

    var app = App.init(dbpool);

    var server = try httpz.Server(*App).init(allocator, .{ .port = port, .address = "0.0.0.0" }, &app);
    defer server.deinit();
    defer server.stop();

    var router = try server.router(.{});
    router.get("/status", handlers.getStatus, .{});

    std.log.info("server started at port: {d}", .{port});
    try server.listen();
}
