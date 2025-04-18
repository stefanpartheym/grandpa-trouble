const std = @import("std");

pub fn SceneManager(comptime CustomContext: type) type {
    return struct {
        const Self = @This();

        pub const Context = struct {
            manager: *Self,
            context: CustomContext,
        };

        pub const Scene = struct {
            pub const VTable = struct {
                init: ?*const fn (*anyopaque, ctx: Context) anyerror!void = null,
                deinit: ?*const fn (*anyopaque, allocator: std.mem.Allocator) void = null,
                update: *const fn (*anyopaque, ctx: Context, delta_time: f32) anyerror!void,
                render: *const fn (*anyopaque) void,
            };

            ptr: *anyopaque,
            vtable: *const VTable,
        };

        /// Utility function to be used in a Scene implementation to cast the
        /// `ptr` to the actual implementation type.
        pub fn ptrCast(comptime T: type, ptr: *anyopaque) *T {
            return @ptrCast(@alignCast(ptr));
        }

        allocator: std.mem.Allocator,
        context: CustomContext,
        stack: std.ArrayList(Scene),

        pub fn init(allocator: std.mem.Allocator, context: CustomContext) Self {
            return Self{
                .allocator = allocator,
                .context = context,
                .stack = std.ArrayList(Scene).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.clear();
            self.stack.deinit();
        }

        pub fn empty(self: *const Self) bool {
            return self.stack.items.len == 0;
        }

        pub fn push(self: *Self, scene: Scene) !void {
            if (scene.vtable.init) |init_fn| {
                try init_fn(scene.ptr, self.getContext());
            }
            try self.stack.append(scene);
        }

        pub fn pop(self: *Self) void {
            const item = self.stack.pop();
            if (item) |scene| {
                if (scene.vtable.deinit) |deinit_fn| {
                    deinit_fn(scene.ptr, self.allocator);
                }
            }
        }

        pub fn replace(self: *Self, scene: Scene) !void {
            self.clear();
            try self.push(scene);
        }

        pub fn update(self: *Self, delta_time: f32) !void {
            const scene = self.current() orelse return;
            try scene.vtable.update(scene.ptr, self.getContext(), delta_time);
        }

        pub fn render(self: *Self) void {
            const scene = self.current() orelse return;
            scene.vtable.render(scene.ptr);
        }

        fn current(self: *Self) ?Scene {
            if (self.stack.items.len > 0) {
                return self.stack.items[self.stack.items.len - 1];
            }
            return null;
        }

        fn getContext(self: *Self) Context {
            return .{
                .manager = self,
                .context = self.context,
            };
        }

        fn clear(self: *Self) void {
            while (!self.empty()) {
                self.pop();
            }
        }
    };
}
