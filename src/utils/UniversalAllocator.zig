//! Platform agnostic allocator frontend, that chooses the appropriate allocator
//! backend based on the host platform.
//! The `GeneralPurposeAllocator` will cause OOM errors for web builds. In such
//! cases the C allocator must be used instead.
//! see: [https://github.com/ziglang/zig/issues/19072](https://github.com/ziglang/zig/issues/19072)

const std = @import("std");
const builtin = @import("builtin");

const Self = @This();
const name = @typeName(Self);
const Gpa = std.heap.GeneralPurposeAllocator(.{});

gpa: ?Gpa,
alt_allocator: ?std.mem.Allocator,

pub fn init() Self {
    // Pick the allocator to use depending on platform.
    return switch (builtin.os.tag) {
        .wasi, .emscripten => Self{
            .gpa = null,
            .alt_allocator = std.heap.c_allocator,
        },
        else => Self{
            .gpa = Gpa{},
            .alt_allocator = null,
        },
    };
}

pub fn deinit(self: *Self) void {
    if (self.gpa) |*gpa| {
        const result = gpa.deinit();
        if (result == .leak) {
            std.debug.print("[WARNING] " ++ name ++ ": Memory leaks detected.", .{});
        }
    }
}

pub fn allocator(self: *Self) std.mem.Allocator {
    return switch (builtin.os.tag) {
        .wasi, .emscripten => self.alt_allocator,
        else => if (self.gpa) |*gpa| gpa.allocator() else null,
    } orelse @panic("No allocator backend available: " ++ name ++ " possibly not initialized.");
}
