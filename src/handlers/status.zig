const std = @import("std");
const httpz = @import("httpz");
const App = @import("../app.zig").App;

pub fn get(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    app.db.ping() catch |err| {
        std.log.err("DB ping failed: {}", .{err});
        try res.json(.{
            .status = "DB ping failed",
            .err = @errorName(err),
        }, .{});
        return;
    };

    std.log.info("200 {} {s}", .{ req.method, req.url.path });
    try res.json(.{
        .status = "OK",
    }, .{});
}
