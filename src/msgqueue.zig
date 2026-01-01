const std = @import("std");

pub fn MsgQueue(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        list: std.ArrayList(T),
        mutex: std.Thread.Mutex,
        cond: std.Thread.Condition,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) !MsgQueue(T) {
            return .{
                .allocator = allocator,
                .list = try std.ArrayList(T).initCapacity(allocator, 1024),
                .mutex = .{},
                .cond = .{},
            };
        }

        pub fn deinit(self: *Self) void {
            self.list.deinit(self.allocator);
        }

        pub fn send(self: *Self, hash: T) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            try self.list.append(self.allocator, hash);
            self.cond.signal(); // tell processor there's work to do
        }

        pub fn receive(self: *Self) ?T {
            self.mutex.lock();
            defer self.mutex.unlock();

            // wait until there is at least one hash in the list
            while (self.list.items.len == 0) {
                self.cond.wait(&self.mutex);
            }

            // get the first item (MsgQueue behavior)
            // return self.list.orderedRemove(0);

            // pop for O(1) and better performance if order doesn't matter
            return self.list.pop();
        }
    };
}
