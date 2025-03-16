const std = @import("std");
const entt = @import("entt");
const comp = @import("../components.zig");
const m = @import("../math/mod.zig");

pub const AnimationSystem = struct {
    const Self = @This();

    reg: *entt.Registry,
    view: entt.MultiView(2, 1),

    pub fn init(reg: *entt.Registry) Self {
        return .{
            .reg = reg,
            .view = reg.view(.{ comp.Visual, comp.Animation }, .{comp.Disabled}),
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn update(self: *Self, delta_time: f32) void {
        var it = self.view.entityIterator();

        while (it.next()) |entity| {
            var visual = self.view.get(comp.Visual, entity);
            var animation = self.view.get(comp.Animation, entity);

            // Update animation frame.
            animation.state.tick(delta_time);

            // Update source rect for current animation frame.
            const padding = animation.definition.padding;
            const frame = animation.state.getCurrentFrame();
            const texture_width = @as(f32, @floatFromInt(visual.sprite.texture.width));
            const texture_height = @as(f32, @floatFromInt(visual.sprite.texture.height));
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

            visual.sprite.rect = source_rect;
        }
    }
};
