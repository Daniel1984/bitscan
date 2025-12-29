const std = @import("std");

pub fn Fifo(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        list: std.ArrayList(T),
        mutex: std.Thread.Mutex,
        cond: std.Thread.Condition,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Fifo(T) {
            return .{
                .allocator = allocator,
                .list = std.ArrayList(T){},
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

        pub fn receive(self: *Self) T {
            self.mutex.lock();
            defer self.mutex.unlock();

            // wait until there is at least one hash in the list
            while (self.list.items.len == 0) {
                self.cond.wait(&self.mutex);
            }

            // get the first item (FIFO behavior)
            return self.list.orderedRemove(0);
        }
    };
}
