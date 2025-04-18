const std = @import("std");

const Self = @This();

state: f32,

pub fn new() Self {
    return .{
        .state = 0,
    };
}

pub fn update(self: *Self, delta: f32) void {
    self.state += delta;
}

pub fn reset(self: *Self) void {
    self.state = 0;
}
