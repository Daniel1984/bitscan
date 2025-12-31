const std = @import("std");
const httpz = @import("httpz");
const Db = @import("./db.zig").Db;
const handlers = @import("./handlers/handlers.zig");

db: *Db,
allocator: std.mem.Allocator,

pub const App = @This();

pub fn notFound(_: *App, req: *httpz.Request, res: *httpz.Response) !void {
    std.log.info("404 {} {s}", .{ req.method, req.url.path });
    res.status = 404;
    res.body = "Not Found";
}

pub fn uncaughtError(_: *App, req: *httpz.Request, res: *httpz.Response, err: anyerror) void {
    std.log.info("500 {} {s} {}", .{ req.method, req.url.path, err });
    res.status = 500;
    res.body = "Oops, something went wrong...";
}

pub fn init(allocator: std.mem.Allocator, db: *Db) App {
    return .{
        .db = db,
        .allocator = allocator,
    };
}

pub fn startApi(self: *App, port: u16) !void {
    var server = try httpz.Server(*App).init(
        self.allocator,
        .{
            .port = port,
            .address = "0.0.0.0",
        },
        self,
    );
    defer server.deinit();
    defer server.stop();

    var router = try server.router(.{});
    router.get("/status", handlers.getStatus, .{});

    std.log.info("HTTP server started on port {d}", .{port});
    try server.listen();
}
