const std = @import("std");
const entt = @import("entt");
const rl = @import("raylib");
const comp = @import("../components.zig");
const m = @import("../math/mod.zig");

pub const RenderSystem = struct {
    const Self = @This();

    reg: *entt.Registry,
    camera: *const rl.Camera2D,
    drawGroup: entt.OwningGroup,

    pub fn init(reg: *entt.Registry, camera: *const rl.Camera2D) Self {
        return .{
            .reg = reg,
            .camera = camera,
            .drawGroup = reg.group(.{ comp.Position, comp.Shape, comp.Visual }, .{}, .{}),
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn beginFrame(_: *const Self, clear_color: ?rl.Color) void {
        rl.beginDrawing();
        rl.clearBackground(clear_color orelse rl.Color.blank);
    }

    pub fn endFrame(_: *const Self) void {
        rl.endDrawing();
    }

    pub fn draw(self: *Self) void {
        // Sort entities based on their `VisualLayer`.
        const context = SortContext{ .reg = self.reg };
        self.drawGroup.sort(entt.Entity, context, SortContext.sort);

        var iter = self.drawGroup.entityIterator();
        while (iter.next()) |entity| {
            if (self.reg.has(comp.Disabled, entity)) continue;
            const pos: comp.Position = self.drawGroup.getConst(comp.Position, entity);
            const shape: comp.Shape = self.drawGroup.getConst(comp.Shape, entity);
            const visual: comp.Visual = self.drawGroup.getConst(comp.Visual, entity);
            if (self.reg.has(comp.ParallaxLayer, entity)) {
                drawParallaxLayer(self.camera, pos, shape, visual);
            } else {
                drawEntity(pos, shape, visual);
            }
        }
    }
};

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

pub fn drawEntity(pos: comp.Position, shape: comp.Shape, visual: comp.Visual) void {
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
fn drawStub(pos: comp.Position, shape: comp.Shape) void {
    drawShape(pos, shape, rl.Color.magenta, false);
}

/// Draw a sprite.
fn drawSprite(
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
fn drawText(
    text: [:0]const u8,
    pos: m.Vec2_i32,
    size: i32,
    color: rl.Color,
) void {
    rl.drawText(text, pos.x(), pos.y(), size, color);
}

/// Generic drawing function to be used for `stub` and `color` visuals.
fn drawShape(pos: comp.Position, shape: comp.Shape, color: rl.Color, outline: bool) void {
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
