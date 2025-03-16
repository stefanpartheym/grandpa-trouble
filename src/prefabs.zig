const std = @import("std");
const entt = @import("entt");
const rl = @import("raylib");
const m = @import("math/mod.zig");
const graphics = @import("graphics/mod.zig");
const entities = @import("entities.zig");
const comp = @import("components.zig");
const coll = @import("collision.zig");

pub const CollisionLayer = struct {
    pub const background: u32 = 0b00000001;
    pub const map: u32 = 0b00000010;
    pub const enemy_colliders: u32 = 0b00000100;
    pub const deadly_colliders: u32 = 0b00001000;
    pub const player: u32 = 0b10000000;
    pub const enemies: u32 = 0b01000000;
    pub const items: u32 = 0b00100000;
    pub const goal: u32 = 0b00010000;
};

pub const VisualLayer = struct {
    pub const background_layer1: i32 = -3;
    pub const background_layer2: i32 = -2;
    pub const background_layer3: i32 = -1;
    pub const map_base_layer: i32 = 0;
    pub const npcs: i32 = 10;
    pub const items: i32 = 10;
    pub const player: i32 = 11;
    pub const floating_text: i32 = 12;
};

pub fn createPlayer(
    reg: *entt.Registry,
    entity: entt.Entity,
    spawn_pos: m.Vec2,
    texture: *const rl.Texture,
    atlas: *graphics.sprites.AnimatedSpriteSheet,
) void {
    const pos = comp.Position.fromVec2(spawn_pos);
    const shape = comp.Shape.new_rectangle(33, 45);
    entities.setAnimated(
        reg,
        entity,
        pos,
        shape,
        texture,
        atlas,
        .{ .name = "player_0", .speed = 1.5 },
        comp.VisualLayer.new(VisualLayer.player),
    );
    entities.setMovable(
        reg,
        entity,
        comp.Speed{ .value = m.Vec2.new(250, 850) },
        comp.Velocity{},
    );
    reg.add(
        entity,
        comp.Collision.new(
            CollisionLayer.player,
            CollisionLayer.map |
                CollisionLayer.enemies |
                CollisionLayer.items |
                CollisionLayer.deadly_colliders |
                CollisionLayer.goal,
            shape.getSize(),
        ),
    );
    reg.add(entity, comp.Gravity.new());
    reg.add(entity, comp.Player{});
}

pub fn createEnemey(
    reg: *entt.Registry,
    enemy_type: comp.EnemyType,
    spawn_pos: m.Vec2,
    shape: comp.Shape,
    texture: *const rl.Texture,
    atlas: *graphics.sprites.AnimatedSpriteSheet,
    animationDefinition: comp.Animation.Definition,
    speed: m.Vec2,
) entt.Entity {
    const e = reg.create();
    entities.setAnimated(
        reg,
        e,
        comp.Position.fromVec2(spawn_pos),
        shape,
        texture,
        atlas,
        animationDefinition,
        comp.VisualLayer.new(VisualLayer.npcs),
    );
    entities.setMovable(
        reg,
        e,
        comp.Speed{ .value = speed },
        comp.Velocity{ .value = m.Vec2.new(-3000, 0) },
    );
    reg.add(e, comp.Enemy{ .type = enemy_type });
    reg.add(e, comp.Collision.new(
        CollisionLayer.enemies,
        CollisionLayer.map | CollisionLayer.enemy_colliders | CollisionLayer.player,
        shape.getSize(),
    ));
    reg.add(e, comp.Gravity.new());
    return e;
}

pub fn createCoin(
    reg: *entt.Registry,
    spawn_pos: m.Vec2,
    texture: *const rl.Texture,
    atlas: *graphics.sprites.AnimatedSpriteSheet,
) entt.Entity {
    const e = reg.create();
    const shape = comp.Shape.new_rectangle(18, 18);
    entities.setAnimated(
        reg,
        e,
        comp.Position.fromVec2(spawn_pos.sub(shape.getSize().scale(0.5))),
        shape,
        texture,
        atlas,
        .{ .name = "coin_0", .speed = 8 },
        comp.VisualLayer.new(VisualLayer.items),
    );
    reg.add(e, comp.Item{ .type = .coin });
    reg.add(e, comp.Collision.new(
        CollisionLayer.items,
        CollisionLayer.player,
        shape.getSize(),
    ));
    return e;
}

pub fn createGoal(
    reg: *entt.Registry,
    spawn_pos: m.Vec2,
    texture: *const rl.Texture,
    atlas: *graphics.sprites.AnimatedSpriteSheet,
) entt.Entity {
    const e = reg.create();
    const scale = 4;
    const shape = comp.Shape.new_rectangle(18 * scale, 30 * scale);
    entities.setAnimated(
        reg,
        e,
        comp.Position.fromVec2(spawn_pos.sub(shape.getSize().scale(0.5))),
        shape,
        texture,
        atlas,
        .{ .name = "portal_0", .speed = 5 },
        comp.VisualLayer.new(VisualLayer.items), // TODO: Use a separate layer.
    );
    reg.add(e, comp.Goal{});
    reg.add(e, comp.Collision.new(
        CollisionLayer.goal,
        CollisionLayer.player,
        shape.getSize(),
    ));
    return e;
}

pub fn createEnemey1(
    reg: *entt.Registry,
    spawn_pos: m.Vec2,
    texture: *const rl.Texture,
    atlas: *graphics.sprites.AnimatedSpriteSheet,
) entt.Entity {
    return createEnemey(
        reg,
        .slow,
        spawn_pos,
        comp.Shape.new_rectangle(18 * 3, 10 * 3),
        texture,
        atlas,
        .{
            .name = "enemies_0",
            .speed = 6,
            .padding = m.Vec4.new(0, 10, 2, 10),
        },
        m.Vec2.new(100, 0),
    );
}

pub fn createEnemey2(
    reg: *entt.Registry,
    spawn_pos: m.Vec2,
    texture: *const rl.Texture,
    atlas: *graphics.sprites.AnimatedSpriteSheet,
) entt.Entity {
    return createEnemey(
        reg,
        .fast,
        spawn_pos,
        comp.Shape.new_rectangle(15 * 3, 17 * 3),
        texture,
        atlas,
        .{
            .name = "enemies_9",
            .speed = 6,
            .padding = m.Vec4.new(2, 3, 4, 3),
        },
        m.Vec2.new(150, 0),
    );
}

pub fn createFloatingText(
    reg: *entt.Registry,
    spawn_pos: m.Vec2,
    text: [:0]const u8,
) entt.Entity {
    const e = reg.create();
    entities.setRenderable(
        reg,
        e,
        comp.Position.fromVec2(spawn_pos),
        comp.Shape.new_rectangle(0, 0),
        comp.Visual.new_text(text, 14, rl.Color.green),
        comp.VisualLayer.new(VisualLayer.floating_text),
    );
    entities.setMovable(
        reg,
        e,
        comp.Speed{ .value = m.Vec2.zero() },
        comp.Velocity{ .value = m.Vec2.new(0, -150) },
    );
    reg.add(e, comp.Lifetime.new(0.5));
    return e;
}

pub fn createParallaxLayer(
    reg: *entt.Registry,
    size: m.Vec2,
    texture: *const rl.Texture,
    tint: rl.Color,
    parallax_layer: comp.ParallaxLayer,
    visual_layer: ?comp.VisualLayer,
) entt.Entity {
    const e = reg.create();
    reg.add(e, parallax_layer);
    var visual = comp.Visual.new_sprite(
        texture,
        m.Rect.new(
            m.Vec2.zero(),
            m.Vec2.new(
                @floatFromInt(texture.width),
                @floatFromInt(texture.height),
            ),
        ),
    );
    visual.sprite.tint = tint;
    entities.setRenderable(
        reg,
        e,
        comp.Position.zero(),
        comp.Shape.new_rectangle(size.x(), size.y()),
        visual,
        visual_layer,
    );
    return e;
}
