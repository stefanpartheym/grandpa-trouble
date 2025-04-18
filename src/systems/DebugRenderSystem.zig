const std = @import("std");
const entt = @import("entt");
const rl = @import("raylib");
const comp = @import("../components.zig");
const m = @import("../math/mod.zig");
const render = @import("./RenderSystem.zig");

const Self = @This();

const DefaultDrawView = entt.MultiView(3, 1);
const VelocityDrawView = entt.MultiView(3, 1);

pub const DebugColors = struct {
    default: rl.Color = rl.Color.yellow,
    velocity: rl.Color = rl.Color.red,
};

reg: *entt.Registry,
camera: *const rl.Camera2D,
colors: DebugColors,
default_view: DefaultDrawView,
velocity_view: VelocityDrawView,

pub fn init(reg: *entt.Registry, camera: *const rl.Camera2D, colors: DebugColors) Self {
    return .{
        .reg = reg,
        .camera = camera,
        .colors = colors,
        .default_view = reg.view(.{ comp.Position, comp.Shape, comp.Visual }, .{comp.Disabled}),
        .velocity_view = reg.view(.{ comp.Position, comp.Shape, comp.Velocity }, .{comp.Disabled}),
    };
}

pub fn deinit(self: *Self) void {
    _ = self;
}

/// Draw entity shape AABB's.
pub fn draw(self: *Self) void {
    var iter = self.default_view.entityIterator();
    while (iter.next()) |entity| {
        var pos = self.default_view.getConst(comp.Position, entity);
        const shape = self.default_view.getConst(comp.Shape, entity);
        if (shape == .circle) {
            pos.x -= shape.getWidth() / 2;
            pos.y -= shape.getHeight() / 2;
        }
        // Draw entity AABB outline.
        render.drawEntity(
            pos,
            comp.Shape.new_rectangle(shape.getWidth(), shape.getHeight()),
            comp.Visual.new_color(self.colors.default, true),
        );
        // If entity is collidable, draw the collision AABB with a slight alpha.
        if (self.reg.tryGet(comp.Collision, entity)) |collision_comp| {
            render.drawEntity(
                pos,
                comp.Shape.new_rectangle(collision_comp.aabb_size.x(), collision_comp.aabb_size.y()),
                comp.Visual.new_color(self.colors.default.alpha(0.25), false),
            );
        }
    }
}

/// Draw entity velocities.
pub fn drawVelocities(self: *Self, delta_time: f32) void {
    var iter = self.velocity_view.entityIterator();
    while (iter.next()) |entity| {
        const pos = self.velocity_view.getConst(comp.Position, entity);
        const shape = self.velocity_view.getConst(comp.Shape, entity);
        const vel = self.velocity_view.getConst(comp.Velocity, entity);
        // Draw entity AABB outline.
        render.drawEntity(
            comp.Position.fromVec2(pos.toVec2().add(vel.value.scale(delta_time))),
            comp.Shape.new_rectangle(shape.getWidth(), shape.getHeight()),
            comp.Visual.new_color(self.colors.velocity, true),
        );
    }
}

/// Draw FPS
pub fn drawFps(_: *const Self) void {
    rl.drawFPS(10, 10);
}
