const std = @import("std");
const rl = @import("raylib");
const entt = @import("entt");
const comp = @import("components.zig");
const m = @import("math/mod.zig");
const u = @import("utils/mod.zig");

//-----------------------------------------------------------------------------
// Collision
//-----------------------------------------------------------------------------

pub const collision = @import("systems/collision.zig");

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

pub fn updateAnimations(reg: *entt.Registry, delta_time: f32) void {
    var view = reg.view(.{comp.Visual}, .{comp.Disabled});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var visual = view.get(comp.Visual, entity);
        if (visual.* == .animation) {
            visual.animation.playing_animation.tick(delta_time);
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

/// Apply gravity to all relevant entities.
pub fn applyGravity(reg: *entt.Registry, force: f32) void {
    var view = reg.view(.{ comp.Velocity, comp.Gravity }, .{comp.Disabled});
    var it = view.entityIterator();
    while (it.next()) |entity| {
        const gravity = view.get(comp.Gravity, entity);
        const gravity_amount = force * gravity.factor;
        var vel = view.get(comp.Velocity, entity);
        vel.value.yMut().* += gravity_amount;
    }
}

/// Clamp to terminal velocity.
pub fn clampVelocity(reg: *entt.Registry) void {
    var view = reg.view(.{comp.Velocity}, .{comp.Disabled});
    var it = view.entityIterator();
    while (it.next()) |entity| {
        var vel: *comp.Velocity = view.get(comp.Velocity, entity);
        const lower = vel.terminal.scale(-1);
        const upper = vel.terminal;
        const vel_clamped = m.Vec2.new(
            std.math.clamp(vel.value.x(), lower.x(), upper.x()),
            std.math.clamp(vel.value.y(), lower.y(), upper.y()),
        );
        vel.value = vel_clamped;
    }
}

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

//-----------------------------------------------------------------------------
// Drawing
//-----------------------------------------------------------------------------

pub fn beginFrame(clear_color: ?rl.Color) void {
    rl.beginDrawing();
    rl.clearBackground(clear_color orelse rl.Color.blank);
}

pub fn endFrame() void {
    rl.endDrawing();
}

/// Draw entity shape AABB's.
pub fn debugDraw(reg: *entt.Registry, color: rl.Color) void {
    var view = reg.view(.{ comp.Position, comp.Shape, comp.Visual }, .{comp.Disabled});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var pos = view.getConst(comp.Position, entity);
        const shape = view.getConst(comp.Shape, entity);
        if (shape == .circle) {
            pos.x -= shape.getWidth() / 2;
            pos.y -= shape.getHeight() / 2;
        }
        // Draw entity AABB outline.
        drawEntity(
            pos,
            comp.Shape.new_rectangle(shape.getWidth(), shape.getHeight()),
            comp.Visual.new_color(color, true),
        );
        // If entity is collidable, draw the collision AABB with a slight alpha.
        if (reg.tryGet(comp.Collision, entity)) |collision_comp| {
            drawEntity(
                pos,
                comp.Shape.new_rectangle(collision_comp.aabb_size.x(), collision_comp.aabb_size.y()),
                comp.Visual.new_color(color.alpha(0.25), false),
            );
        }
    }
}

/// Draw entity velocities.
pub fn debugDrawVelocity(reg: *entt.Registry, color: rl.Color, delta_time: f32) void {
    var view = reg.view(.{ comp.Position, comp.Shape, comp.Velocity }, .{comp.Disabled});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const pos = view.getConst(comp.Position, entity);
        const shape = view.getConst(comp.Shape, entity);
        const vel = view.getConst(comp.Velocity, entity);
        // Draw entity AABB outline.
        drawEntity(
            comp.Position.fromVec2(pos.toVec2().add(vel.value.scale(delta_time))),
            comp.Shape.new_rectangle(shape.getWidth(), shape.getHeight()),
            comp.Visual.new_color(color, true),
        );
    }
}

/// Draw FPS
pub fn debugDrawFps() void {
    rl.drawFPS(10, 10);
}

pub fn draw(reg: *entt.Registry, camera: *const rl.Camera2D) void {
    const SortContext = struct {
        const Self = @This();

        reg: *entt.Registry,
        default_layer: comp.VisualLayer = comp.VisualLayer.new(0),

        /// Compare function to sort entities by their `VisualLayer`.
        fn sort(self: Self, a: entt.Entity, b: entt.Entity) bool {
            const a_layer = self.reg.tryGetConst(comp.VisualLayer, a) orelse self.default_layer;
            const b_layer = self.reg.tryGetConst(comp.VisualLayer, b) orelse self.default_layer;
            return a_layer.value > b_layer.value;
        }
    };

    // PERF: The group can be created once after the registry is initialized.
    var group = reg.group(.{ comp.Position, comp.Shape, comp.Visual }, .{}, .{});

    // Sort entities based on their `VisualLayer`.
    const context = SortContext{ .reg = reg };
    group.sort(entt.Entity, context, SortContext.sort);

    var iter = group.entityIterator();
    while (iter.next()) |entity| {
        if (reg.has(comp.Disabled, entity)) continue;
        const pos: comp.Position = group.getConst(comp.Position, entity);
        const shape: comp.Shape = group.getConst(comp.Shape, entity);
        const visual: comp.Visual = group.getConst(comp.Visual, entity);
        if (reg.has(comp.ParallaxLayer, entity)) {
            drawParallaxLayer(camera, pos, shape, visual);
        } else {
            drawEntity(pos, shape, visual);
        }
    }
}

fn drawParallaxLayer(
    camera: *const rl.Camera2D,
    pos: comp.Position,
    shape: comp.Shape,
    visual: comp.Visual,
) void {
    const screen_width: f32 = @floatFromInt(rl.getScreenWidth());
    const reps = std.math.ceil((screen_width + shape.getWidth()) / shape.getWidth()) + 2;
    const draw_offset = std.math.ceil(camera.target.x / shape.getWidth()) - 2;
    for (0..@intFromFloat(reps)) |i| {
        const index: f32 = @floatFromInt(i);
        const offset_x = shape.getWidth() * (index + draw_offset);
        const new_pos = pos.toVec2().add(m.Vec2.new(offset_x, 0));
        drawEntity(
            comp.Position.fromVec2(new_pos),
            shape,
            visual,
        );
    }
}

fn drawEntity(pos: comp.Position, shape: comp.Shape, visual: comp.Visual) void {
    switch (visual) {
        .stub => drawStub(pos, shape),
        .color => drawShape(pos, shape, visual.color.value, visual.color.outline),
        .sprite => drawSprite(
            .{
                .x = pos.x,
                .y = pos.y,
                .width = shape.getWidth(),
                .height = shape.getHeight(),
            },
            visual.sprite.rect,
            visual.sprite.texture.*,
            visual.sprite.tint,
        ),
        .text => drawText(visual.text.value, pos.toVec2().cast(i32), visual.text.size, visual.text.color),
        .animation => {
            var animation = visual.animation;
            const padding = animation.definition.padding;
            const frame = animation.playing_animation.getCurrentFrame();
            const texture_width = @as(f32, @floatFromInt(animation.texture.width));
            const texture_height = @as(f32, @floatFromInt(animation.texture.height));
            const flip_sign_x: f32 = if (animation.definition.flip_x) -1 else 1;
            const flip_sign_y: f32 = if (animation.definition.flip_y) -1 else 1;
            const frame_size = m.Vec2.new(
                texture_width * (frame.region.u_2 - frame.region.u),
                texture_height * (frame.region.v_2 - frame.region.v),
            );
            const source_rect = m.Rect{
                .x = texture_width * frame.region.u + padding.x(),
                .y = texture_height * frame.region.v + padding.y(),
                .width = (frame_size.x() - padding.z()) * flip_sign_x,
                .height = (frame_size.y() - padding.w()) * flip_sign_y,
            };
            drawSprite(
                .{
                    .x = pos.x,
                    .y = pos.y,
                    .width = shape.getWidth(),
                    .height = shape.getHeight(),
                },
                source_rect,
                animation.texture.*,
                null,
            );
        },
    }
}

/// Draw  a stub shape.
/// TODO: Make visual appearance more noticeable.
pub fn drawStub(pos: comp.Position, shape: comp.Shape) void {
    drawShape(pos, shape, rl.Color.magenta, false);
}

/// Draw a sprite.
pub fn drawSprite(
    target: m.Rect,
    source: m.Rect,
    texture: rl.Texture,
    tint: ?rl.Color,
) void {
    texture.drawPro(
        .{
            .x = source.x,
            .y = source.y,
            .width = source.width,
            .height = source.height,
        },
        .{
            .x = target.x,
            .y = target.y,
            .width = target.width,
            .height = target.height,
        },
        .{ .x = 0, .y = 0 },
        0,
        tint orelse rl.Color.white,
    );
}

/// Draw text.
pub fn drawText(
    text: [:0]const u8,
    pos: m.Vec2_i32,
    size: i32,
    color: rl.Color,
) void {
    rl.drawText(text, pos.x(), pos.y(), size, color);
}

/// Generic drawing function to be used for `stub` and `color` visuals.
pub fn drawShape(pos: comp.Position, shape: comp.Shape, color: rl.Color, outline: bool) void {
    const p: rl.Vector2 = .{ .x = pos.x, .y = pos.y };
    switch (shape) {
        .triangle => {
            const v1: rl.Vector2 = .{
                .x = p.x + shape.triangle.v1.x(),
                .y = p.y + shape.triangle.v1.y(),
            };
            const v2: rl.Vector2 = .{
                .x = p.x + shape.triangle.v2.x(),
                .y = p.y + shape.triangle.v2.y(),
            };
            const v3: rl.Vector2 = .{
                .x = p.x + shape.triangle.v3.x(),
                .y = p.y + shape.triangle.v3.y(),
            };
            if (outline) {
                rl.drawTriangleLines(v1, v2, v3, color);
            } else {
                rl.drawTriangle(v1, v2, v3, color);
            }
        },
        .rectangle => {
            const size: rl.Vector2 = .{ .x = shape.rectangle.width, .y = shape.rectangle.height };
            if (outline) {
                // NOTE: The `drawRectangleLines` function draws the outlined
                // rectangle incorrectly. Hence, drawing the lines individually.
                const v1: rl.Vector2 = .{ .x = p.x, .y = p.y };
                const v2: rl.Vector2 = .{ .x = p.x + size.x, .y = p.y };
                const v3: rl.Vector2 = .{ .x = p.x + size.x, .y = p.y + size.y };
                const v4: rl.Vector2 = .{ .x = p.x, .y = p.y + size.y };
                rl.drawLineV(v1, v2, color);
                rl.drawLineV(v2, v3, color);
                rl.drawLineV(v3, v4, color);
                rl.drawLineV(v4, v1, color);
            } else {
                rl.drawRectangleV(p, size, color);
            }
        },
        .circle => {
            if (outline) {
                rl.drawCircleLinesV(p, shape.circle.radius, color);
            } else {
                rl.drawCircleV(p, shape.circle.radius, color);
            }
        },
    }
}
