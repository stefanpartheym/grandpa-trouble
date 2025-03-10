const std = @import("std");
const rl = @import("raylib");
const entt = @import("entt");
const m = @import("math/mod.zig");
const sprites = @import("graphics/mod.zig").sprites;
const Timer = @import("timer.zig").Timer;
const Rect = m.Rect;
const Vec2 = m.Vec2;
const collision = @import("collision.zig");

//------------------------------------------------------------------------------
// Common components
//------------------------------------------------------------------------------

/// Controls if an entity is being processed (updated, rendered, etc.) or not.
/// Used to disable entities that are not visible in the current frame.
/// This drastically improves performance. Especially when there is no need to
/// check collisions for not visible entities.
pub const Disabled = struct {
    value: u8 = 1,
};

pub const Position = struct {
    const Self = @This();

    x: f32,
    y: f32,

    pub fn new(x: f32, y: f32) Self {
        return Self{
            .x = x,
            .y = y,
        };
    }

    pub fn fromVec2(value: m.Vec2) Self {
        return new(value.x(), value.y());
    }

    pub fn toVec2(self: *const Self) m.Vec2 {
        return m.Vec2.new(self.x, self.y);
    }

    pub fn zero() Self {
        return Self.new(0, 0);
    }
};

pub const Velocity = struct {
    /// Current velocity.
    value: m.Vec2 = m.Vec2.zero(),
    /// Maximum velocity per frame an entity can reach.
    terminal: m.Vec2 = m.Vec2.new(300, 1000),
};

pub const Speed = struct {
    value: m.Vec2,
};

pub const Direction = enum {
    const Self = @This();

    none,
    up,
    down,
    left,
    right,

    pub fn normal(self: Self) m.Vec2 {
        return switch (self) {
            // NOTE:
            // Direction `up` and `down` return their counterpart.
            // `Vec2` uses a cartesian coordinate system (y axis grows up) and
            // we are using a raster coordinate system (y axis grows down).
            // Therfore, `up` and `down` must be negated.
            .up => m.Vec2.up().negate(),
            .down => m.Vec2.down().negate(),
            .left => m.Vec2.left(),
            .right => m.Vec2.right(),
            .none => m.Vec2.zero(),
        };
    }

    pub fn reverse(self: Self) Direction {
        return switch (self) {
            .up => .down,
            .down => .up,
            .left => .right,
            .right => .left,
            .none => .none,
        };
    }
};

pub const Movement = struct {
    const Self = @This();

    direction: Direction,
    previous_direction: Direction,
    next_direction: Direction,

    pub fn new(direction: Direction) Self {
        return Self{
            .direction = direction,
            .next_direction = direction,
            .previous_direction = direction,
        };
    }

    pub fn update(self: *Self, direction: Direction) void {
        self.previous_direction = self.direction;
        self.direction = direction;
        // self.next_direction = direction;
    }
};

pub const ShapeType = enum {
    triangle,
    rectangle,
    circle,
};

pub const Shape = union(ShapeType) {
    const Self = @This();

    triangle: struct {
        v1: Vec2,
        v2: Vec2,
        v3: Vec2,
    },
    rectangle: struct {
        width: f32,
        height: f32,
    },
    circle: struct {
        radius: f32,
    },

    pub fn new_triangle(v1: Vec2, v2: Vec2, v3: Vec2) Self {
        return Self{
            .triangle = .{
                .v1 = v1,
                .v2 = v2,
                .v3 = v3,
            },
        };
    }

    pub fn new_rectangle(width: f32, height: f32) Self {
        return Self{
            .rectangle = .{
                .width = width,
                .height = height,
            },
        };
    }

    pub fn new_circle(radius: f32) Self {
        return Self{
            .circle = .{ .radius = radius },
        };
    }

    pub fn getWidth(self: *const Self) f32 {
        switch (self.*) {
            .triangle => return self.getTriangleVectorLength().x(),
            .rectangle => return self.rectangle.width,
            .circle => return self.circle.radius * 2,
        }
    }

    pub fn getHeight(self: *const Self) f32 {
        switch (self.*) {
            .triangle => return self.getTriangleVectorLength().y(),
            .rectangle => return self.rectangle.height,
            .circle => return self.circle.radius * 2,
        }
    }

    /// TODO: Rename to `toVec2`.
    pub fn getSize(self: *const Self) m.Vec2 {
        return m.Vec2.new(self.getWidth(), self.getHeight());
    }

    fn getTriangleVectorLength(self: *const Self) Vec2 {
        const v1 = self.triangle.v1;
        const v2 = self.triangle.v2;
        const v3 = self.triangle.v3;
        return m.Vec2.max(m.Vec2.max(v1, v2), v3);
    }
};

pub const VisualType = enum {
    stub,
    color,
    sprite,
    text,
    animation,
};

/// Enables sorting entities by their layer to control the order in which they
/// are drawn.
pub const VisualLayer = struct {
    const Self = @This();
    value: i32,
    pub fn new(value: i32) Self {
        return Self{ .value = value };
    }
};

pub const Visual = union(VisualType) {
    const Self = @This();
    pub const AnimationDefinition = struct {
        name: []const u8,
        loop: bool = true,
        speed: f32 = 1,
        flip_x: bool = false,
        flip_y: bool = false,
        /// Frame padding.
        padding: m.Vec4 = m.Vec4.zero(),
        /// Start at a given frame.
        frame: ?usize = null,

        pub fn eql(self: @This(), other: @This()) bool {
            return std.mem.eql(u8, self.name, other.name) and
                self.loop == other.loop and
                self.speed == other.speed and
                self.flip_x == other.flip_x and
                self.flip_y == other.flip_y and
                self.padding.eql(other.padding);
        }
    };

    stub: struct {
        /// In order for the ECS to correctly handle the component, it needs at
        /// least one property.
        value: u8,
    },
    color: struct {
        value: rl.Color,
        outline: bool,
    },
    sprite: struct {
        texture: *const rl.Texture,
        /// Position and dimensions of the sprite on the texture.
        rect: Rect,
        tint: rl.Color = rl.Color.white,
    },
    text: struct {
        // TODO: Add font.
        // font: rl.Font,
        size: i32,
        color: rl.Color,
        value: [:0]const u8,
    },
    animation: struct {
        texture: *const rl.Texture,
        animation: *sprites.AnimatedSpriteSheet,
        definition: AnimationDefinition,
        playing_animation: sprites.PlayingAnimation,

        pub fn changeAnimation(
            self: *@This(),
            definition: AnimationDefinition,
        ) void {
            if (self.definition.eql(definition)) {
                return;
            }
            self.definition = definition;
            self.playing_animation = self.animation.playAnimation(definition.name).?;
            self.playing_animation.loop(definition.loop);
            self.playing_animation.setSpeed(definition.speed);
            self.playing_animation.play();
            if (definition.frame) |start_frame| {
                self.playing_animation.frame = start_frame;
            }
        }

        pub fn freeze(self: *@This()) void {
            self.playing_animation.pause();
        }
    },

    /// Creates a stub Visual component.
    pub fn new_stub() Self {
        return Self{
            .stub = .{ .value = 1 },
        };
    }

    /// Creates a stub Visual component.
    pub fn new_color(value: rl.Color, outline: bool) Self {
        return Self{
            .color = .{
                .value = value,
                .outline = outline,
            },
        };
    }

    pub fn new_sprite(
        texture: *const rl.Texture,
        rect: ?Rect,
    ) Self {
        return Self{
            .sprite = .{
                .texture = texture,
                .rect = rect orelse Rect.new(
                    m.Vec2.zero(),
                    m.Vec2.new(@floatFromInt(texture.width), @floatFromInt(texture.height)),
                ),
            },
        };
    }

    pub fn new_text(
        value: [:0]const u8,
        size: i32,
        text_color: rl.Color,
    ) Self {
        return Self{
            .text = .{
                .value = value,
                .size = size,
                .color = text_color,
            },
        };
    }

    pub fn new_animation(
        texture: *const rl.Texture,
        anim: *sprites.AnimatedSpriteSheet,
        definition: AnimationDefinition,
    ) Self {
        var playing_animation = anim.playAnimation(definition.name).?;
        playing_animation.setSpeed(definition.speed);
        playing_animation.loop(definition.loop);
        playing_animation.play();
        return Self{
            .animation = .{
                .texture = texture,
                .animation = anim,
                .definition = definition,
                .playing_animation = playing_animation,
            },
        };
    }
};

pub const ParallaxLayer = struct {
    scroll_factor: m.Vec2,
    /// Static offset.
    offset: m.Vec2 = m.Vec2.zero(),
};

pub const Lifetime = struct {
    const Self = @This();

    /// Lifetime value in seconds.
    state: f32,

    pub fn new(value: f32) Self {
        return Self{ .state = value };
    }

    pub fn update(self: *Self, value: f32) void {
        self.state -= value;
    }

    pub fn dead(self: *const Self) bool {
        return self.state <= 0;
    }
};

pub const Cooldown = struct {
    const Self = @This();

    /// Cooldown value in seconds.
    value: f32,
    /// Current cooldown state.
    state: f32 = 0,
    /// Number of resets.
    resets: u32 = 0,

    pub fn new(value: f32) Self {
        return Self{ .value = value };
    }

    pub fn reset(self: *Self) void {
        self.state = self.value;
        self.resets += 1;
    }

    pub fn set(self: *Self, value: f32) void {
        self.value = value;
        self.reset();
    }

    pub fn update(self: *Self, delta_time: f32) void {
        self.state -= @min(delta_time, self.state);
    }

    pub fn ready(self: *const Self) bool {
        return self.state == 0;
    }
};

//------------------------------------------------------------------------------
// Physics
//------------------------------------------------------------------------------

pub const Collision = struct {
    const Self = @This();

    /// Collision layer.
    layer: u32,
    /// Collision mask.
    mask: u32,
    /// AABB
    /// TODO: Add property for offset to entitiy's position.
    aabb_size: m.Vec2,
    /// Collision normal.
    /// Will contain the normals the entity collided with in the last frame.
    normal: m.Vec2,

    pub fn new(layer: u32, mask: u32, aabb_size: m.Vec2) Self {
        return Self{
            .layer = layer,
            .mask = mask,
            .aabb_size = aabb_size,
            .normal = m.Vec2.zero(),
        };
    }

    /// Check if two entities can collide with each other.
    pub fn canCollide(self: Collision, other: Collision) bool {
        return (self.mask & other.layer) != 0;
    }

    pub fn grounded(self: *const Self) bool {
        return self.normal.y() < 0;
    }

    /// Set collision normals.
    pub fn setNormals(self: *Self, normal: m.Vec2) void {
        if (normal.x() != 0) {
            self.normal.xMut().* = normal.x();
        }
        if (normal.y() != 0) {
            self.normal.yMut().* = normal.y();
        }
    }
};

pub const Gravity = struct {
    const Self = @This();

    /// Factor which the default gravity force is modulated with.
    factor: f32,

    pub fn new() Self {
        return Self.fromFactor(1);
    }

    pub fn fromFactor(factor: f32) Self {
        return Self{ .factor = factor };
    }
};

//------------------------------------------------------------------------------
// Game specific components
//------------------------------------------------------------------------------

/// TODO:
/// Player component is currently only used for checks in collision system.
/// It should be removed as we already store the player entity in the game state.
pub const Player = struct {
    value: u8 = 0,
};

pub const EnemyType = enum {
    slow,
    fast,
};

pub const Enemy = struct {
    type: EnemyType,
    value: u8 = 0,
};

/// The player will die, when colliding with an entity with this component.
pub const DeadlyCollider = struct {
    value: u8 = 0,
};

pub const ItemType = enum {
    coin,
};

pub const Item = struct {
    type: ItemType,
    value: u8 = 0,
};

pub const Goal = struct {
    value: u8 = 0,
};
