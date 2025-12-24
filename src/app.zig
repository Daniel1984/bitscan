const std = @import("std");
const httpz = @import("httpz");
const Db = @import("./db.zig").Db;

db: *Db,

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

pub fn init(db: *Db) App {
    return .{
        .db = db,
    };
}
