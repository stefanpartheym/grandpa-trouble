//! Contains all game related state.

const std = @import("std");
const rl = @import("raylib");
const entt = @import("entt");
const graphics = @import("graphics/mod.zig");
const m = @import("math/mod.zig");
const application = @import("application.zig");
const tiled = @import("tiled.zig");
const Timer = @import("timer.zig").Timer;
const coll = @import("collision.zig");
const comp = @import("components.zig");
const prefabs = @import("prefabs.zig");
const ecs = struct {
    const systems = @import("systems.zig");
    const entities = @import("entities.zig");
};

const FloatingText = struct {
    pub const score_10: [:0]const u8 = "+10";
    pub const score_20: [:0]const u8 = "+20";
};

const ScoreInfo = struct {
    value: u32,
    text: [:0]const u8,
};

const State = enum {
    ready,
    paused,
    playing,
    won,
    lost,
    gameover,
};

const Entities = struct {
    reg: *entt.Registry,
    player: ?entt.Entity,

    pub fn new(reg: *entt.Registry) @This() {
        return .{ .player = null, .reg = reg };
    }

    pub fn clear(self: *@This()) void {
        self.player = null;
    }

    /// Get the player entity.
    /// Creates the player entity if it doe not yet exist.
    pub fn getPlayer(self: *@This()) entt.Entity {
        if (self.player == null) {
            // TODO: Return an error rather than implicitly creating the entity.
            self.player = self.reg.create();
        }
        return self.player.?;
    }

    /// Returns the players center position.
    pub fn getPlayerCenter(self: *@This()) m.Vec2 {
        const entity = self.getPlayer();
        const pos = self.reg.get(comp.Position, entity);
        const shape = self.reg.get(comp.Shape, entity);
        return pos.toVec2().add(shape.getSize().scale(0.5));
    }
};

pub const Systems = struct {
    collision: ecs.systems.collision.CollisionSystem,
    physics: ecs.systems.physics.PhysicsSystem,
    render: ecs.systems.render.RenderSystem,
    debug_render: ecs.systems.debug_render.DebugRenderSystem,
    animation: ecs.systems.animation.AnimationSystem,

    pub fn deinit(self: *@This()) void {
        self.animation.deinit();
        self.debug_render.deinit();
        self.render.deinit();
        self.physics.deinit();
        self.collision.deinit();
    }
};

pub const Sprites = struct {
    tileset_texture: rl.Texture,
    player_texture: rl.Texture,
    player_atlas: graphics.sprites.AnimatedSpriteSheet,
    portal_texture: rl.Texture,
    portal_atlas: graphics.sprites.AnimatedSpriteSheet,
    enemies_texture: rl.Texture,
    enemies_atlas: graphics.sprites.AnimatedSpriteSheet,
    coin_texture: rl.Texture,
    coin_atlas: graphics.sprites.AnimatedSpriteSheet,
    background_layer_1_texture: rl.Texture,
    background_layer_2_texture: rl.Texture,
    background_layer_3_texture: rl.Texture,
    ui_pause: rl.Texture,
    ui_heart: rl.Texture,
    ui_coin: rl.Texture,

    pub fn deinit(self: *@This()) void {
        self.tileset_texture.unload();
        self.player_texture.unload();
        self.player_atlas.deinit();
        self.portal_texture.unload();
        self.portal_atlas.deinit();
        self.enemies_texture.unload();
        self.enemies_atlas.deinit();
        self.coin_texture.unload();
        self.coin_atlas.deinit();
        self.ui_pause.unload();
        self.ui_heart.unload();
        self.ui_coin.unload();
        self.background_layer_1_texture.unload();
        self.background_layer_2_texture.unload();
        self.background_layer_3_texture.unload();
    }
};

pub const Sounds = struct {
    soundtrack: rl.Music,
    jump: rl.Sound,
    hit: rl.Sound,
    die: rl.Sound,
    portal: rl.Sound,
    pickup_coin: rl.Sound,

    pub fn deinit(self: *@This()) void {
        rl.unloadMusicStream(self.soundtrack);
        rl.unloadSound(self.jump);
        rl.unloadSound(self.hit);
        rl.unloadSound(self.die);
        rl.unloadSound(self.portal);
        rl.unloadSound(self.pickup_coin);
    }
};

const Self = @This();

state: State,
next_state: ?State,
app: *application.Application,
config: *application.ApplicationConfig,
reg: *entt.Registry,

entities: Entities,
systems: *Systems,
sprites: *Sprites,
sounds: *Sounds,
tilemap: *tiled.Tilemap,
camera: *rl.Camera2D,

debug_mode: bool,
audio_enabled: bool,
score: u32,
lives: u8,
/// Tracks the time elapsed since the the player started the game.
/// When the player pauses the game, the timer is also paused.
level_timer: Timer,
/// Time in seconds the player has to finish the level.
level_time: f32,
/// Tracks when to change to the next state.
state_timer: Timer,
/// Time in seconds until the next state will be applied.
state_delay: f32,

pub fn new(
    app: *application.Application,
    reg: *entt.Registry,
    systems: *Systems,
    sprites: *Sprites,
    sounds: *Sounds,
    tilemap: *tiled.Tilemap,
    camera: *rl.Camera2D,
) Self {
    return Self{
        .state = .ready,
        .next_state = null,
        .app = app,
        .config = &app.config,
        .reg = reg,
        .entities = Entities.new(reg),
        .systems = systems,
        .sprites = sprites,
        .sounds = sounds,
        .tilemap = tilemap,
        .camera = camera,
        .debug_mode = false,
        .audio_enabled = true,
        .score = 0,
        .lives = 3,
        .level_timer = Timer.new(),
        .level_time = 100,
        .state_timer = Timer.new(),
        .state_delay = 0,
    };
}

pub fn update(self: *Self, dt: f32) !void {
    if (self.state == .playing) {
        self.level_timer.update(dt);
        if (self.next_state == null and self.level_timer.state >= self.level_time) {
            self.killPlayer();
        }
    }
    if (self.next_state) |next_state| {
        self.state_timer.update(dt);
        if (self.state_timer.state >= self.state_delay) {
            self.transition(next_state);
            self.next_state = null;
        }
    }

    // App input
    try self.handleAppInput();

    if (self.state == .playing) {
        ecs.systems.disableNotVisible(self.reg, self.camera);
        ecs.systems.updateLifetimes(self.reg, dt);

        // Player input
        if (self.next_state == null) {
            self.handlePlayerInput(dt);
        }

        // AI
        self.updateEnemies();

        // Physics
        try self.systems.physics.update(dt);
        self.handleCollisions(&self.systems.collision, dt);
        ecs.systems.updatePosition(self.reg, dt);

        // Graphics
        if (self.next_state == null) {
            // Do not update camera when player died.
            graphics.camera.updateCameraTarget(
                self.camera,
                self.entities.getPlayerCenter(),
                m.Vec2.new(0.3, 0.3),
            );
        }
        ecs.systems.scrollParallaxLayers(self.reg, self.camera);
        self.systems.animation.update(dt);
    }
}

pub fn render(self: *Self) void {
    {
        self.camera.begin();
        self.systems.render.draw();
        if (self.debug_mode) {
            self.systems.debug_render.draw();
            // TODO: Delta time not available in render.
            // self.systems.debug_render.drawVelocities(dt);
        }
        self.camera.end();
    }
    self.drawHud();
    if (self.debug_mode) self.systems.debug_render.drawFps();
}

pub fn setState(self: *Self, new_state: State) void {
    if (self.next_state == null) {
        self.transition(new_state);
        self.next_state = null;
    }
}

fn changeState(self: *Self, next_state: State, delay: f32) void {
    self.next_state = next_state;
    self.state_timer.reset();
    if (delay == 0) {
        self.setState(next_state);
    } else {
        self.state_delay = delay;
    }
}

fn updateScore(self: *Self, value: u32) void {
    self.score += value;
}

fn playSound(self: *const Self, sound: rl.Sound) void {
    if (self.audio_enabled) {
        rl.playSound(sound);
    }
}

/// Transitions to the next state.
fn transition(self: *Self, next_state: State) void {
    var new_state = next_state;
    switch (self.state) {
        .won, .gameover, .ready => switch (next_state) {
            .playing => {
                self.level_timer.reset();
                self.lives = 3;
                self.score = 0;
                // TODO: catch unreachable for now to avoid error handling.
                self.reset() catch unreachable;
            },
            else => @panic("Invalid state transition"),
        },
        .lost => switch (next_state) {
            .playing => {
                self.level_timer.reset();
                // TODO: catch unreachable for now to avoid error handling.
                self.restart() catch unreachable;
            },
            else => @panic("Invalid state transition"),
        },
        .playing => switch (next_state) {
            .paused, .won => {},
            .lost => {
                self.lives -= 1;
                if (self.lives == 0) {
                    new_state = .gameover;
                }
            },
            else => @panic("Invalid state transition"),
        },
        .paused => switch (next_state) {
            .playing => {},
            else => @panic("Invalid state transition"),
        },
    }
    // Apply new state.
    self.state = new_state;
}

//------------------------------------------------------------------------------
// Gameplay
//------------------------------------------------------------------------------

fn handleAppInput(self: *Self) !void {
    if (rl.isKeyPressed(.f1)) {
        self.debug_mode = !self.debug_mode;
    }

    if (rl.isKeyPressed(.f2)) {
        self.audio_enabled = !self.audio_enabled;
    }

    // Toggle camera zoom (for debugging).
    if (rl.isKeyPressed(.f3)) {
        self.camera.zoom = if (self.camera.zoom == 1)
            graphics.camera.getCameraZoom()
        else
            1;
    }

    if (rl.isKeyPressed(.enter)) {
        switch (self.state) {
            .playing => self.setState(.paused),
            .ready, .paused, .won, .lost, .gameover => self.setState(.playing),
        }
    }
}

fn handlePlayerInput(game: *Self, dt: f32) void {
    const reg = game.reg;
    const player_entity = game.entities.getPlayer();
    const collision = reg.get(comp.Collision, player_entity);
    const speed = reg.get(comp.Speed, player_entity).value;
    var vel = reg.get(comp.Velocity, player_entity);
    var animation = reg.get(comp.Animation, player_entity);

    const last_animation = animation.definition;
    var next_animation = comp.Animation.Definition{
        .name = "player_0",
        .speed = 1.5,
        // Inherit flip flag from last animation.
        .flip_x = last_animation.flip_x,
    };

    const accel_factor: f32 = if (collision.grounded()) 4 else 2.5;
    const decel_factor: f32 = if (collision.grounded()) 15 else 0.5;
    const acceleration = speed.x() * accel_factor * dt;

    // Move left.
    if (rl.isKeyDown(.h) or rl.isKeyDown(.left)) {
        vel.value.xMut().* = std.math.clamp(vel.value.x() - acceleration, -speed.x(), speed.x());
        next_animation = .{ .name = "player_1", .speed = 10, .flip_x = true };
    }
    // Move right.
    else if (rl.isKeyDown(.l) or rl.isKeyDown(.right)) {
        vel.value.xMut().* = std.math.clamp(vel.value.x() + acceleration, -speed.x(), speed.x());
        next_animation = .{ .name = "player_1", .speed = 10, .flip_x = false };
    }
    // Gradually stop moving.
    else {
        const vel_amount = @abs(vel.value.x());
        const amount = @min(vel_amount, vel_amount * decel_factor * dt);
        vel.value.xMut().* -= amount * std.math.sign(vel.value.x());
        if (@abs(vel.value.x()) < 0.01) vel.value.xMut().* = 0;
    }

    // Jump.
    if (rl.isKeyPressed(.space) and vel.value.y() == 0) {
        vel.value.yMut().* = -speed.y();
        game.playSound(game.sounds.jump);
    }

    // Set jump animation if player is in the air.
    if (!collision.grounded()) {
        next_animation = .{
            .name = "player_1",
            .speed = 0,
            // Inherit flip flag from current movement.
            .flip_x = next_animation.flip_x,
            .frame = 1,
        };
    }

    animation.change(next_animation);
}

fn spawnPlayer(game: *Self) !void {
    const player_spawn_object = try game.tilemap.data.getObject("player_spawn");
    const spawn_pos = m.Vec2.new(player_spawn_object.x, player_spawn_object.y);
    prefabs.createPlayer(
        game.reg,
        game.entities.getPlayer(),
        spawn_pos,
        &game.sprites.player_texture,
        &game.sprites.player_atlas,
    );
}

/// Restart current level and preserve player progress.
fn restart(game: *Self) !void {
    game.reg.destroy(game.entities.getPlayer());
    game.entities.clear();
    try spawnPlayer(game);
}

/// Reset game state.
fn reset(game: *Self) !void {
    const reg = game.reg;

    // Clear entity references.
    game.entities.clear();

    // Delete all entities.
    var it = reg.entities();
    while (it.next()) |entity| {
        reg.destroy(entity);
    }

    // Setup background layers.
    {
        const screen_size = m.Vec2.new(
            game.config.getDisplayWidth(),
            game.config.getDisplayHeight(),
        );
        const tint = rl.Color.init(61, 56, 70, 255);
        _ = prefabs.createParallaxLayer(
            game.reg,
            screen_size.scale(2),
            &game.sprites.background_layer_1_texture,
            tint,
            comp.ParallaxLayer{
                .scroll_factor = m.Vec2.new(0.02, 0),
                .offset = m.Vec2.new(0, -200),
            },
            comp.VisualLayer.new(prefabs.VisualLayer.background_layer1),
        );
        _ = prefabs.createParallaxLayer(
            game.reg,
            screen_size.scale(1),
            &game.sprites.background_layer_2_texture,
            tint,
            comp.ParallaxLayer{
                .scroll_factor = m.Vec2.new(0.05, 0),
                .offset = m.Vec2.new(0, 400),
            },
            comp.VisualLayer.new(prefabs.VisualLayer.background_layer2),
        );
        _ = prefabs.createParallaxLayer(
            game.reg,
            screen_size.scale(1),
            &game.sprites.background_layer_3_texture,
            tint,
            comp.ParallaxLayer{
                .scroll_factor = m.Vec2.new(0.1, 0),
                .offset = m.Vec2.new(0, 700),
            },
            comp.VisualLayer.new(prefabs.VisualLayer.background_layer3),
        );
    }

    const tilemap = game.tilemap;
    const debug_map_scale = 1;

    const map_size = m.Vec2.new(
        @floatFromInt(tilemap.data.width * tilemap.data.tilewidth),
        @floatFromInt(tilemap.data.height * tilemap.data.tileheight),
    );
    const total_map_size = map_size.scale(debug_map_scale);

    // Setup map boundaries.
    {
        const left = reg.create();
        reg.add(left, comp.Position.new(0, 0));
        reg.add(left, comp.Collision.new(prefabs.CollisionLayer.map, 0, total_map_size.mul(m.Vec2.new(0, 1))));
        const right = reg.create();
        reg.add(right, comp.Position.new(total_map_size.x(), 0));
        reg.add(right, comp.Collision.new(prefabs.CollisionLayer.map, 0, total_map_size.mul(m.Vec2.new(0, 1))));
    }

    // Setup tilemap.
    {
        const tileset = try tilemap.getTileset(1);
        const shape = comp.Shape.new_rectangle(
            @floatFromInt(tilemap.data.tilewidth),
            @floatFromInt(tilemap.data.tileheight),
        );
        for (0..debug_map_scale) |debug_map_scale_index| {
            for (tilemap.data.layers, 0..) |layer, layer_index| {
                if (!layer.visible or layer.type != .tilelayer) continue;
                const layer_index_i32: i32 = @intCast(layer_index);
                var x: usize = 0;
                var y: usize = 0;
                for (layer.tiles) |tile_id| {
                    // Skip empty tiles.
                    if (tile_id != 0) {
                        const entity = reg.create();
                        const relative_pos = m.Vec2.new(
                            @floatFromInt(x * tilemap.data.tilewidth),
                            @floatFromInt(y * tilemap.data.tileheight),
                        );
                        const debug_map_scale_factor = m.Vec2.new(@floatFromInt(debug_map_scale_index), 0);
                        const pos = relative_pos.add(map_size.mul(debug_map_scale_factor));
                        ecs.entities.setRenderable(
                            reg,
                            entity,
                            comp.Position.fromVec2(pos),
                            shape,
                            comp.Visual.new_sprite(&game.sprites.tileset_texture, tileset.getSpriteRect(tile_id)),
                            comp.VisualLayer.new(prefabs.VisualLayer.map_base_layer + layer_index_i32),
                        );
                        // Add collision for first layer only.
                        if (layer.id < 2) {
                            reg.add(entity, comp.Collision.new(prefabs.CollisionLayer.map, 0, shape.getSize()));
                        }
                    }

                    // Update next tile position.
                    x += 1;
                    if (x >= tilemap.data.width) {
                        x = 0;
                        y += 1;
                    }
                }
            }
        }
    }

    // Setup enemy colliders
    {
        var objects_it = tilemap.data.objects_by_id.valueIterator();
        while (objects_it.next()) |object| {
            if (std.mem.eql(u8, object.*.type, "enemy_collider")) {
                const pos = m.Vec2.new(object.*.x, object.*.y);
                const shape = comp.Shape.new_rectangle(object.*.width, object.*.height);
                const entity = reg.create();
                reg.add(entity, comp.Position.fromVec2(pos));
                reg.add(entity, shape);
                reg.add(entity, comp.Collision.new(prefabs.CollisionLayer.enemy_colliders, 0, shape.getSize()));
            }
        }
    }

    // Setup player colliders.
    // Player colliding with these will kill the player.
    {
        var objects_it = tilemap.data.objects_by_id.valueIterator();
        while (objects_it.next()) |object| {
            if (std.mem.eql(u8, object.*.type, "player_death")) {
                const pos = m.Vec2.new(object.*.x, object.*.y);
                const shape = comp.Shape.new_rectangle(object.*.width, object.*.height);
                const entity = reg.create();
                reg.add(entity, comp.DeadlyCollider{});
                reg.add(entity, comp.Position.fromVec2(pos));
                reg.add(entity, shape);
                reg.add(entity, comp.Collision.new(
                    prefabs.CollisionLayer.deadly_colliders,
                    0,
                    shape.getSize(),
                ));
            }
        }
    }

    // Setup new player entity.
    try spawnPlayer(game);

    // Spawn enemies.
    {
        var objects_it = tilemap.data.objects_by_id.valueIterator();
        while (objects_it.next()) |object| {
            const spawn_pos = m.Vec2.new(object.*.x, object.*.y);
            if (std.mem.eql(u8, object.*.type, "enemy1_spawn")) {
                _ = prefabs.createEnemey1(game.reg, spawn_pos, &game.sprites.enemies_texture, &game.sprites.enemies_atlas);
            } else if (std.mem.eql(u8, object.*.type, "enemy2_spawn")) {
                _ = prefabs.createEnemey2(game.reg, spawn_pos, &game.sprites.enemies_texture, &game.sprites.enemies_atlas);
            }
        }
    }

    // Spawn items.
    {
        var objects_it = tilemap.data.objects_by_id.valueIterator();
        while (objects_it.next()) |object| {
            if (std.mem.eql(u8, object.*.type, "coin")) {
                const spawn_pos = m.Vec2.new(object.*.x, object.*.y);
                _ = prefabs.createCoin(game.reg, spawn_pos, &game.sprites.coin_texture, &game.sprites.coin_atlas);
            }
        }
    }

    // Setup goal.
    {
        var objects_it = tilemap.data.objects_by_id.valueIterator();
        while (objects_it.next()) |object| {
            if (std.mem.eql(u8, object.*.type, "goal")) {
                const spawn_pos = m.Vec2.new(object.*.x, object.*.y);
                _ = prefabs.createGoal(game.reg, spawn_pos, &game.sprites.portal_texture, &game.sprites.portal_atlas);
            }
        }
    }
}

fn killPlayer(game: *Self) void {
    if (game.entities.player == null) @panic("No player entity present");

    game.playSound(game.sounds.die);

    const reg = game.reg;
    const e = game.entities.getPlayer();

    // Change collision mask to avoid further collision.
    var collision = reg.get(comp.Collision, e);
    collision.mask = 0;
    collision.layer = prefabs.CollisionLayer.background;

    // Make player bounce before death and stop moving horizontally.
    const speed = reg.get(comp.Speed, e);
    var vel = reg.get(comp.Velocity, e);
    vel.value = m.Vec2.new(0, -speed.value.y() * 0.5);

    // Play death animation.
    var animation = reg.get(comp.Animation, e);
    animation.change(.{
        .name = "player_2",
        .speed = 0,
        .loop = false,
        .flip_x = animation.definition.flip_x,
        .padding = animation.definition.padding,
    });

    game.changeState(.lost, 1);
}

fn playerWin(game: *Self) void {
    if (game.entities.player == null) @panic("No player entity present");

    game.playSound(game.sounds.portal);

    const reg = game.reg;
    const e = game.entities.getPlayer();

    // Make the player move slowly towards the goal.
    reg.remove(comp.Collision, e);
    reg.remove(comp.Gravity, e);
    const speed = reg.get(comp.Speed, e);
    var vel = reg.get(comp.Velocity, e);
    vel.value = m.Vec2.new(speed.value.x() * 0.25, 0);

    game.changeState(.won, 0.6);
}

fn killEnemy(self: *Self, entity: entt.Entity) void {
    self.playSound(self.sounds.hit);

    const reg = self.reg;

    const enemy = reg.get(comp.Enemy, entity);
    const score_info = switch (enemy.type) {
        .slow => ScoreInfo{ .text = FloatingText.score_10, .value = 10 },
        .fast => ScoreInfo{ .text = FloatingText.score_20, .value = 20 },
    };
    self.updateScore(score_info.value);
    const pos = reg.get(comp.Position, entity);
    _ = prefabs.createFloatingText(self.reg, pos.toVec2(), score_info.text);

    // Add a lifetime component to make the entity disappear
    // after lifetime ended.
    reg.add(entity, comp.Lifetime.new(1));

    // Remove Enemy component to avoid unnecessary updates.
    reg.remove(comp.Enemy, entity);

    // Set velocity to zero.
    var enemy_vel = reg.get(comp.Velocity, entity);
    enemy_vel.value = m.Vec2.zero();

    // Shrink enemy size to half.
    var enemy_shape = reg.get(comp.Shape, entity);
    enemy_shape.rectangle.height *= 0.5;
    var enemy_collision = reg.get(comp.Collision, entity);
    enemy_collision.aabb_size = enemy_collision.aabb_size.mul(m.Vec2.new(1, 0.5));

    // Avoid further collision with player.
    enemy_collision.mask = enemy_collision.mask & ~prefabs.CollisionLayer.player;
    enemy_collision.layer = prefabs.CollisionLayer.background;

    // Freeze animation.
    var enemy_animation = reg.get(comp.Animation, entity);
    enemy_animation.freeze();
}

fn pickupItem(self: *Self, entity: entt.Entity) void {
    const ItemInfo = struct {
        score: ScoreInfo,
        sound: rl.Sound,
    };
    const item = self.reg.getConst(comp.Item, entity);
    const item_info = switch (item.type) {
        .coin => ItemInfo{
            .score = ScoreInfo{ .text = FloatingText.score_20, .value = 20 },
            .sound = self.sounds.pickup_coin,
        },
    };
    self.playSound(item_info.sound);
    self.updateScore(item_info.score.value);
    const pos = self.reg.getConst(comp.Position, entity);
    _ = prefabs.createFloatingText(self.reg, pos.toVec2(), item_info.score.text);
    self.reg.destroy(entity);
}

fn updateEnemies(self: *Self) void {
    const reg = self.reg;
    var view = reg.view(.{ comp.Enemy, comp.Velocity, comp.Speed, comp.Collision }, .{comp.Disabled});
    var it = view.entityIterator();
    while (it.next()) |entity| {
        const speed = view.get(comp.Speed, entity);
        var vel = view.get(comp.Velocity, entity);
        var animation = view.get(comp.Animation, entity);
        const collision = view.get(comp.Collision, entity);
        // Reverse direction if collision occurred on x axis.
        const direction = if (collision.normal.x() == 0) std.math.sign(vel.value.x()) else collision.normal.x();
        const direction_speed = speed.value.mul(m.Vec2.new(direction, 0));
        const flip_x = direction < 0;
        animation.change(.{
            .name = animation.definition.name,
            .speed = animation.definition.speed,
            .padding = animation.definition.padding,
            .flip_x = flip_x,
        });
        vel.value.xMut().* = direction_speed.x();
    }
}

fn handleCollisions(
    self: *Self,
    collision_system: *ecs.systems.collision.CollisionSystem,
    delta_time: f32,
) void {
    const reg = self.reg;
    for (collision_system.queue.items()) |collision| {
        var vel = reg.get(comp.Velocity, collision.entity);
        var collision_comp = reg.get(comp.Collision, collision.entity);
        const relative_vel = vel.value.sub(collision.collider_vel).scale(delta_time);
        const result = coll.aabbToAabb(collision.entity_aabb, collision.collider_aabb, relative_vel);
        if (result.hit) {
            const entity_is_player = reg.has(comp.Player, collision.entity);
            const collider_is_player = reg.has(comp.Player, collision.collider);
            const entity_is_enemy = reg.has(comp.Enemy, collision.entity);
            const collider_is_enemy = reg.has(comp.Enemy, collision.collider);

            const collide_with_enemy = entity_is_enemy or collider_is_enemy;
            const collide_deadly = reg.has(comp.DeadlyCollider, collision.entity) or reg.has(comp.DeadlyCollider, collision.collider);
            const collide_item = reg.has(comp.Item, collision.entity) or reg.has(comp.Item, collision.collider);
            const collide_goal = reg.has(comp.Goal, collision.entity) or reg.has(comp.Goal, collision.collider);

            const use_entity_specific_response =
                (entity_is_player or collider_is_player) and
                (collide_with_enemy or collide_deadly or collide_item or collide_goal);

            // Use entity-specific collision response.
            // This is relevant, if the player collides with an enemy, a deadly collider or an item.
            // Make sure the player is still alive when handling the collision.
            // If the player is already dead, calling `killPlayer()` again will
            // crash the game, because adding/removing certain components will
            // fail.
            if (use_entity_specific_response and self.next_state != .lost) {
                if (collide_with_enemy) {
                    const kill_enemy_normal: f32 = if (collider_is_player) 1 else -1;
                    if (result.normal.y() == kill_enemy_normal) {
                        const enemy_entity = if (entity_is_enemy) collision.entity else collision.collider;
                        killEnemy(self, enemy_entity);
                        // Make player bounce off the top of the enemy.
                        const player = self.entities.getPlayer();
                        const player_speed = reg.get(comp.Speed, player);
                        const player_vel = reg.get(comp.Velocity, player);
                        player_vel.value.yMut().* = -player_speed.value.y() * 0.5;
                    } else {
                        killPlayer(self);
                    }
                } else if (collide_deadly) {
                    killPlayer(self);
                } else if (collide_item) {
                    pickupItem(self, collision.collider);
                } else if (collide_goal) {
                    playerWin(self);
                }
            }
            // Use default collision response.
            else {
                // Correct velocity to resolve collision.
                vel.value = coll.resolveCollision(result, vel.value);
                // Set collision normals.
                collision_comp.setNormals(result.normal);
                // TODO: Disabled, since we're not handling dynamic vs. dynamic collisions here.
                // // Resolve collision for dynamic collider.
                // if (reg.tryGet(comp.Velocity, collision.entity)) |collider_vel| {
                //     collider_vel.value = coll.resolveCollision(result, collider_vel.value);
                //     var collider_collision = reg.get(comp.Collision, collision.entity);
                //     collider_collision.normal = collision_comp.normal.scale(-1);
                // }
            }
        }
    }
}

fn drawHud(self: *Self) void {
    const font = rl.getFontDefault() catch unreachable;
    const font_size = 20;
    const text_spacing = 2;
    const symbol_scale = 3;
    const padding = 10;
    var offset: i32 = padding;

    const ally = self.app.allocator;

    // Draw lives.
    {
        const symbol_size: i32 = @intCast(self.sprites.ui_heart.width);
        const symbols_width = @as(i32, @intCast(self.lives)) * symbol_size * symbol_scale;
        for (0..self.lives) |i| {
            const index: i32 = @intCast(i);
            const offset_x = rl.getScreenWidth() - offset - symbols_width + index * symbol_size * symbol_scale;
            self.sprites.ui_heart.drawEx(
                rl.Vector2.init(@floatFromInt(offset_x), @floatFromInt(offset)),
                0,
                symbol_scale,
                rl.Color.ray_white,
            );
        }
        offset += symbol_size * symbol_scale;
    }

    // Draw score.
    {
        const symbol_size: i32 = @intCast(self.sprites.ui_coin.width);
        const offset_x = rl.getScreenWidth() - padding - symbol_size * symbol_scale;
        self.sprites.ui_coin.drawEx(
            rl.Vector2.init(@floatFromInt(offset_x), @floatFromInt(offset + padding)),
            0,
            symbol_scale,
            rl.Color.ray_white,
        );

        // Draw score text.
        {
            const text = std.fmt.allocPrintZ(ally, "{d}", .{self.score}) catch unreachable;
            const text_size = rl.measureTextEx(font, text, font_size, text_spacing);
            defer ally.free(text);
            const offset_x_text = offset_x - @as(i32, @intFromFloat(text_size.x));
            rl.drawText(
                text,
                @intCast(offset_x_text - padding),
                offset + padding + @divTrunc(symbol_size * symbol_scale, 2) - @as(i32, @intFromFloat(text_size.y / 2)),
                font_size,
                rl.Color.ray_white,
            );
        }
    }

    // Draw timer.
    {
        const text = std.fmt.allocPrintZ(
            ally,
            "TIME: {d:0>3.0}",
            .{self.level_time - self.level_timer.state},
        ) catch unreachable;
        const text_size = rl.measureTextEx(font, text, font_size, text_spacing);
        defer ally.free(text);
        const offset_x = rl.getScreenWidth() - padding - @as(i32, @intFromFloat(text_size.x));
        rl.drawText(
            text,
            @intCast(offset_x),
            rl.getScreenHeight() - padding - @as(i32, @intFromFloat(text_size.y)),
            font_size,
            rl.Color.ray_white,
        );
    }

    switch (self.state) {
        .playing => {},
        .paused => graphics.text.drawSymbolAndTextCenteredHorizontally(
            "PAUSED",
            padding,
            font,
            font_size,
            text_spacing,
            padding,
            &self.sprites.ui_pause,
            symbol_scale,
        ),
        .won => graphics.text.drawTextCentered(
            "Level completed!\nPress ENTER to continue.",
            font_size,
            rl.Color.ray_white,
        ),
        .lost => graphics.text.drawTextCentered(
            "You died!\nPress ENTER to restart.",
            font_size,
            rl.Color.ray_white,
        ),
        .gameover => graphics.text.drawTextCentered(
            "GAME OVER!\nPress ENTER to restart.",
            font_size,
            rl.Color.ray_white,
        ),
        else => unreachable,
    }
}
