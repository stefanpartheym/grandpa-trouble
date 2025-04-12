const std = @import("std");

pub const Stopwatch = struct {
    const Self = @This();

    enabled: bool,
    start_ns: i128,
    stop_ns: i128,

    pub fn new(enabled: bool) Self {
        return Self{
            .enabled = enabled,
            .start_ns = undefined,
            .stop_ns = undefined,
        };
    }

    pub fn start(self: *Self) void {
        self.start_ns = std.time.nanoTimestamp();
    }

    pub fn stop(self: *Self) i128 {
        self.stop_ns = std.time.nanoTimestamp();
        return self.stop_ns - self.start_ns;
    }

    pub fn print(self: *Self, title: [:0]const u8) void {
        const duration_ns = self.stop();
        if (self.enabled) {
            const duration_ms: f128 = @as(f128, @floatFromInt(duration_ns)) / @as(f128, @floatFromInt(std.time.ns_per_ms));
            std.debug.print("[ Stopwatch] {s}: {d} ms\n", .{ title, duration_ms });
        }
    }
};
