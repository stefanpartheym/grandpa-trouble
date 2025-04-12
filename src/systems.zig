const std = @import("std");
const rl = @import("raylib");
const entt = @import("entt");
const comp = @import("components.zig");
const m = @import("math/mod.zig");
const u = @import("utils/mod.zig");

pub const render = @import("systems/render.zig");
pub const debug_render = @import("systems/debug_render.zig");
pub const animation = @import("systems/animation.zig");
pub const collision = @import("systems/collision.zig");
pub const physics = @import("systems/physics.zig");

//-----------------------------------------------------------------------------
// Misc
//-----------------------------------------------------------------------------

pub fn updateLifetimes(reg: *entt.Registry, delta_time: f32) void {
    var view = reg.view(.{comp.Lifetime}, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var lifetime = view.get(entity);
        lifetime.update(delta_time);
        if (lifetime.dead()) {
            reg.destroy(entity);
        }
    }
}

// pub fn enableAll(reg: *entt.Registry) void {
//     var view = reg.view(.{comp.Disabled}, .{});
//     var iter = view.entityIterator();
//     while (iter.next()) |entity| {
//         reg.remove(comp.Disabled, entity);
//     }
// }

/// Disable entities that are not visible in the current frame and enable the
/// ones that are visible.
pub fn disableNotVisible(reg: *entt.Registry, camera: *const rl.Camera2D) void {
    // A negative margin will cause entities, that are slightly out of view to
    // also be enabled. This makes everything feel a bit more natural.
    const margin: f32 = -50;
    // Calculate camera bounds in world space.
    const camera_unzoom = 1 / camera.zoom;
    const camera_offset = u.rl.toVec2(camera.offset);
    const camera_min = u.rl.toVec2(camera.target)
        .sub(camera_offset.scale(camera_unzoom))
        .add(m.Vec2.new(margin, margin));
    const render_size = m.Vec2.new(
        @floatFromInt(rl.getRenderWidth()),
        @floatFromInt(rl.getRenderHeight()),
    );
    const screen_size = render_size
        .scale(camera_unzoom)
        .sub(m.Vec2.new(margin, margin).scale(2));
    const camera_bounds = m.Rect.new(camera_min, screen_size);

    var view = reg.view(.{ comp.Position, comp.Shape, comp.Visual }, .{comp.ParallaxLayer});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const pos = view.get(comp.Position, entity);
        const shape = view.get(comp.Shape, entity);
        const entity_bounds = m.Rect.new(pos.toVec2(), shape.getSize());
        // Enable entity, if visible and not already enabled.
        if (entity_bounds.overlapsRect(camera_bounds)) {
            reg.removeIfExists(comp.Disabled, entity);
        }
        // Disable entity, if not visible and not already disabled.
        else if (!reg.has(comp.Disabled, entity)) {
            reg.add(entity, comp.Disabled{});
        }
    }
}

pub fn scrollParallaxLayers(reg: *entt.Registry, camera: *const rl.Camera2D) void {
    const camera_target = m.Vec2.new(camera.target.x, camera.target.y);
    var view = reg.view(.{ comp.Position, comp.Shape, comp.ParallaxLayer }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var pos = view.get(comp.Position, entity);
        // const shape = view.getConst(comp.Shape, entity);
        const parallax_layer = view.getConst(comp.ParallaxLayer, entity);
        var offset = camera_target
            .mul(m.Vec2.new(-1, -1))
            .mul(parallax_layer.scroll_factor)
            .add(parallax_layer.offset);
        pos.x = offset.x();
        pos.y = offset.y();
    }
}

//-----------------------------------------------------------------------------
// Physics
//-----------------------------------------------------------------------------

/// Update entities position based on their velocity.
pub fn updatePosition(reg: *entt.Registry, delta_time: f32) void {
    var view = reg.view(.{ comp.Position, comp.Velocity }, .{comp.Disabled});
    var it = view.entityIterator();
    while (it.next()) |entity| {
        const vel = view.getConst(comp.Velocity, entity);
        const vel_scaled = vel.value.scale(delta_time);
        var pos = view.get(comp.Position, entity);
        pos.x += vel_scaled.x();
        pos.y += vel_scaled.y();
    }
}
