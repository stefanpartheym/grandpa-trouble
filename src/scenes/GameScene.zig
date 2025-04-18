const std = @import("std");
const rl = @import("raylib");
const entt = @import("entt");
const paa = @import("../paa.zig");
const m = @import("../math/mod.zig");
const u = @import("../utils/mod.zig");
const graphics = @import("../graphics/mod.zig");
const application = @import("../application.zig");
const SceneManager = @import("./scene_manager.zig").SceneManager;
const Game = @import("../game.zig").Game;
const tiled = @import("../tiled.zig");
const entities = @import("../entities.zig");
const comp = @import("../components.zig");
const systems = @import("../systems.zig");
const coll = @import("../collision.zig");
const prefabs = @import("../prefabs.zig");

pub const GameScene = struct {
    const Self = @This();
    pub const init = Self{
        .initialized = false,
        .reg = undefined,
        .game = undefined,
        .camera = undefined,
        .tilemap = undefined,
        .assets = undefined,
        .systems = undefined,
    };

    initialized: bool,
    reg: entt.Registry,
    game: Game,
    camera: rl.Camera2D,
    tilemap: tiled.Tilemap,
    assets: struct {
        textures: struct {
            tileset_texture: rl.Texture,
            player_texture: rl.Texture,
            player_atlas: graphics.sprites.AnimatedSpriteSheet,
            portal_texture: rl.Texture,
            portal_atlas: graphics.sprites.AnimatedSpriteSheet,
            enemies_texture: rl.Texture,
            enemies_atlas: graphics.sprites.AnimatedSpriteSheet,
            coin_texture: rl.Texture,
            coin_atlas: graphics.sprites.AnimatedSpriteSheet,
            ui_pause: rl.Texture,
            ui_heart: rl.Texture,
            ui_coin: rl.Texture,
            background_layer_1_texture: rl.Texture,
            background_layer_2_texture: rl.Texture,
            background_layer_3_texture: rl.Texture,

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
        },
        sounds: struct {
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
        },

        pub fn deinit(self: *@This()) void {
            self.textures.deinit();
            self.sounds.deinit();
        }
    },
    systems: struct {
        collision: systems.collision.CollisionSystem,
        physics: systems.physics.PhysicsSystem,
        render: systems.render.RenderSystem,
        debug_render: systems.debug_render.DebugRenderSystem,
        animation: systems.animation.AnimationSystem,

        pub fn deinit(self: *@This()) void {
            self.collision.deinit();
            self.physics.deinit();
            self.render.deinit();
            self.debug_render.deinit();
            self.animation.deinit();
        }
    },

    pub fn scene(self: *Self) SceneManager.Scene {
        return .{
            .ptr = self,
            .vtable = &.{
                .init = init_fn,
                .deinit = deinit,
                .update = update,
                .render = render,
            },
        };
    }

    fn init_fn(ptr: *anyopaque, ctx: SceneManager.Context) !void {
        var self = SceneManager.ptrCast(Self, ptr);
        const ally = ctx.manager.allocator;

        self.reg = entt.Registry.init(ally);
        errdefer self.reg.deinit();

        self.camera = rl.Camera2D{
            .target = .{ .x = 0, .y = 0 },
            .offset = .{ .x = 0, .y = 0 },
            .rotation = 0,
            .zoom = graphics.camera.getCameraZoom(),
        };

        // Load tilemap
        self.tilemap = try tiled.Tilemap.fromFile(ally, "./assets/map/map.tmj");
        errdefer self.tilemap.deinit();

        // Load sprites
        const tileset = try self.tilemap.getTileset(1);
        self.assets.textures.tileset_texture = try u.rl.loadTexture(ally, tileset.image_path);
        errdefer self.assets.textures.tileset_texture.unload();
        self.assets.textures.player_texture = try rl.loadTexture("./assets/player.atlas.png");
        errdefer self.assets.textures.player_texture.unload();
        self.assets.textures.player_atlas = try graphics.sprites.AnimatedSpriteSheet.initFromGrid(ally, 3, 4, "player_");
        errdefer self.assets.textures.player_atlas.deinit();
        self.assets.textures.portal_texture = try rl.loadTexture("./assets/portal.atlas.png");
        errdefer self.assets.textures.portal_texture.unload();
        self.assets.textures.portal_atlas = try graphics.sprites.AnimatedSpriteSheet.initFromGrid(ally, 2, 3, "portal_");
        errdefer self.assets.textures.portal_atlas.deinit();
        self.assets.textures.enemies_texture = try rl.loadTexture("./assets/enemies.atlas.png");
        errdefer self.assets.textures.enemies_texture.unload();
        self.assets.textures.enemies_atlas = try graphics.sprites.AnimatedSpriteSheet.initFromGrid(ally, 12, 2, "enemies_");
        errdefer self.assets.textures.enemies_atlas.deinit();
        self.assets.textures.coin_texture = try rl.loadTexture("./assets/coin.atlas.png");
        errdefer self.assets.textures.coin_texture.unload();
        self.assets.textures.coin_atlas = try graphics.sprites.AnimatedSpriteSheet.initFromGrid(ally, 1, 8, "coin_");
        errdefer self.assets.textures.coin_atlas.deinit();

        // Load Backgrounds
        self.assets.textures.background_layer_1_texture = try rl.loadTexture("./assets/map/background_layer_1.png");
        errdefer self.assets.textures.background_layer_1_texture.unload();
        self.assets.textures.background_layer_2_texture = try rl.loadTexture("./assets/map/background_layer_2.png");
        errdefer self.assets.textures.background_layer_2_texture.unload();
        self.assets.textures.background_layer_3_texture = try rl.loadTexture("./assets/map/background_layer_3.png");
        errdefer self.assets.textures.background_layer_3_texture.unload();

        // Load UI sprites
        self.assets.textures.ui_pause = try rl.loadTexture("./assets/ui/pause_noborder_white.png");
        errdefer self.assets.textures.ui_pause.unload();
        self.assets.textures.ui_heart = try rl.loadTexture("./assets/ui/heart_shaded.png");
        errdefer self.assets.textures.ui_heart.unload();
        self.assets.textures.ui_coin = try rl.loadTexture("./assets/ui/coin_shaded.png");
        errdefer self.assets.textures.ui_coin.unload();

        // Load sounds
        self.assets.sounds.soundtrack = try rl.loadMusicStream("./assets/soundtrack.wav");
        errdefer rl.unloadMusicStream(self.assets.sounds.soundtrack);
        self.assets.sounds.jump = try rl.loadSound("./assets/sounds/jump.wav");
        errdefer rl.unloadSound(self.assets.sounds.jump);
        self.assets.sounds.hit = try rl.loadSound("./assets/sounds/hit.wav");
        errdefer rl.unloadSound(self.assets.sounds.hit);
        self.assets.sounds.die = try rl.loadSound("./assets/sounds/die.wav");
        errdefer rl.unloadSound(self.assets.sounds.die);
        self.assets.sounds.portal = try rl.loadSound("./assets/sounds/portal.wav");
        errdefer rl.unloadSound(self.assets.sounds.portal);
        self.assets.sounds.pickup_coin = try rl.loadSound("./assets/sounds/pickup_coin.wav");
        errdefer rl.unloadSound(self.assets.sounds.pickup_coin);

        self.game = Game.new(ctx.context.app, &self.reg, reset, restart, killPlayer);
        self.game.tilemap = &self.tilemap;
        self.game.sprites.tileset_texture = &self.assets.textures.tileset_texture;
        self.game.sprites.player_texture = &self.assets.textures.player_texture;
        self.game.sprites.player_atlas = &self.assets.textures.player_atlas;
        self.game.sprites.portal_texture = &self.assets.textures.portal_texture;
        self.game.sprites.portal_atlas = &self.assets.textures.portal_atlas;
        self.game.sprites.enemies_texture = &self.assets.textures.enemies_texture;
        self.game.sprites.enemies_atlas = &self.assets.textures.enemies_atlas;
        self.game.sprites.item_coin_texture = &self.assets.textures.coin_texture;
        self.game.sprites.item_coin_atlas = &self.assets.textures.coin_atlas;
        self.game.sprites.background_layer_1_texture = &self.assets.textures.background_layer_1_texture;
        self.game.sprites.background_layer_2_texture = &self.assets.textures.background_layer_2_texture;
        self.game.sprites.background_layer_3_texture = &self.assets.textures.background_layer_3_texture;
        self.game.sprites.ui_pause = &self.assets.textures.ui_pause;
        self.game.sprites.ui_heart = &self.assets.textures.ui_heart;
        self.game.sprites.ui_coin = &self.assets.textures.ui_coin;
        self.game.sounds.soundtrack = self.assets.sounds.soundtrack;
        self.game.sounds.jump = self.assets.sounds.jump;
        self.game.sounds.hit = self.assets.sounds.hit;
        self.game.sounds.die = self.assets.sounds.die;
        self.game.sounds.portal = self.assets.sounds.portal;
        self.game.sounds.pickup_coin = self.assets.sounds.pickup_coin;

        // Initialize systems
        self.systems = .{
            .collision = systems.collision.CollisionSystem.init(ally),
            .physics = systems.physics.PhysicsSystem.init(&self.reg, &self.systems.collision),
            .render = systems.render.RenderSystem.init(&self.reg, &self.camera),
            .debug_render = systems.debug_render.DebugRenderSystem.init(&self.reg, &self.camera, .{}),
            .animation = systems.animation.AnimationSystem.init(&self.reg),
        };

        self.initialized = true;

        self.game.setState(.playing);
    }

    fn deinit(ptr: *anyopaque, _: std.mem.Allocator) void {
        const self = SceneManager.ptrCast(Self, ptr);
        self.systems.deinit();
        self.assets.deinit();
        self.tilemap.deinit();
        self.reg.deinit();
        self.initialized = false;
    }

    fn update(ptr: *anyopaque, ctx: SceneManager.Context, dt: f32) !void {
        const self = SceneManager.ptrCast(Self, ptr);

        // Loop soundtrack.
        if (self.game.audio_enabled) {
            if (!rl.isMusicStreamPlaying(self.game.sounds.soundtrack)) {
                rl.playMusicStream(self.game.sounds.soundtrack);
            }
            rl.updateMusicStream(self.game.sounds.soundtrack);
        }
        // Pause soundtrack, if audio is disabled.
        else {
            rl.pauseMusicStream(self.game.sounds.soundtrack);
        }

        self.game.update(dt);

        // App input
        try handleAppInput(self, ctx);

        if (self.game.state == .playing) {
            systems.disableNotVisible(self.game.reg, &self.camera);
            systems.updateLifetimes(self.game.reg, dt);

            // Player input
            if (self.game.next_state == null) {
                handlePlayerInput(&self.game, dt);
            }

            // AI
            updateEnemies(&self.game);

            // Physics
            try self.systems.physics.update(dt);
            handleCollisions(&self.game, &self.systems.collision, dt);
            systems.updatePosition(self.game.reg, dt);

            // Graphics
            if (self.game.next_state == null) {
                // Do not update camera when player died.
                graphics.camera.updateCameraTarget(
                    &self.camera,
                    self.game.entities.getPlayerCenter(),
                    m.Vec2.new(0.3, 0.3),
                );
            }
            systems.scrollParallaxLayers(self.game.reg, &self.camera);
            self.systems.animation.update(dt);
        }
    }

    fn render(ptr: *anyopaque) void {
        var self = SceneManager.ptrCast(Self, ptr);
        rl.clearBackground(rl.Color.fromInt(0x2a252000));
        {
            self.camera.begin();
            self.systems.render.draw();
            if (self.game.debug_mode) {
                self.systems.debug_render.draw();
                // TODO:Delta time
                self.systems.debug_render.drawVelocities(0);
            }
            self.camera.end();
        }
        drawHud(&self.game);
        if (self.game.debug_mode) self.systems.debug_render.drawFps();
    }
};

const FloatingText = struct {
    pub const score_10: [:0]const u8 = "+10";
    pub const score_20: [:0]const u8 = "+20";
};

const ScoreInfo = struct {
    value: u32,
    text: [:0]const u8,
};

fn handleAppInput(self: *GameScene, ctx: SceneManager.Context) !void {
    if (rl.isKeyPressed(.escape) or rl.isKeyPressed(.q)) {
        try ctx.manager.push(ctx.context.game_menu_scene.scene());
    }

    if (rl.isKeyPressed(.f1)) {
        self.game.toggleDebugMode();
    }

    if (rl.isKeyPressed(.f2)) {
        self.game.toggleAudio();
    }

    // Toggle camera zoom (for debugging).
    if (rl.isKeyPressed(.f3)) {
        self.camera.zoom = if (self.camera.zoom == 1)
            graphics.camera.getCameraZoom()
        else
            1;
    }

    if (rl.isKeyPressed(.r)) {
        reset(&self.game) catch unreachable;
    }

    if (rl.isKeyPressed(.enter)) {
        switch (self.game.state) {
            .playing => self.game.setState(.paused),
            .paused, .won, .lost, .gameover => self.game.setState(.playing),
            else => unreachable,
        }
    }
}

//------------------------------------------------------------------------------
// Game
//------------------------------------------------------------------------------

fn handlePlayerInput(game: *Game, dt: f32) void {
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

fn spawnPlayer(game: *Game) !void {
    const player_spawn_object = try game.tilemap.data.getObject("player_spawn");
    const spawn_pos = m.Vec2.new(player_spawn_object.x, player_spawn_object.y);
    prefabs.createPlayer(
        game.reg,
        game.entities.getPlayer(),
        spawn_pos,
        game.sprites.player_texture,
        game.sprites.player_atlas,
    );
}

/// Restart current level and preserve player progress.
fn restart(game: *Game) !void {
    game.reg.destroy(game.entities.getPlayer());
    game.entities.clear();
    try spawnPlayer(game);
}

/// Reset game state.
fn reset(game: *Game) !void {
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
            game.sprites.background_layer_1_texture,
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
            game.sprites.background_layer_2_texture,
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
            game.sprites.background_layer_3_texture,
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
                        entities.setRenderable(
                            reg,
                            entity,
                            comp.Position.fromVec2(pos),
                            shape,
                            comp.Visual.new_sprite(game.sprites.tileset_texture, tileset.getSpriteRect(tile_id)),
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
                _ = prefabs.createEnemey1(game.reg, spawn_pos, game.sprites.enemies_texture, game.sprites.enemies_atlas);
            } else if (std.mem.eql(u8, object.*.type, "enemy2_spawn")) {
                _ = prefabs.createEnemey2(game.reg, spawn_pos, game.sprites.enemies_texture, game.sprites.enemies_atlas);
            }
        }
    }

    // Spawn items.
    {
        var objects_it = tilemap.data.objects_by_id.valueIterator();
        while (objects_it.next()) |object| {
            if (std.mem.eql(u8, object.*.type, "coin")) {
                const spawn_pos = m.Vec2.new(object.*.x, object.*.y);
                _ = prefabs.createCoin(game.reg, spawn_pos, game.sprites.item_coin_texture, game.sprites.item_coin_atlas);
            }
        }
    }

    // Setup goal.
    {
        var objects_it = tilemap.data.objects_by_id.valueIterator();
        while (objects_it.next()) |object| {
            if (std.mem.eql(u8, object.*.type, "goal")) {
                const spawn_pos = m.Vec2.new(object.*.x, object.*.y);
                _ = prefabs.createGoal(game.reg, spawn_pos, game.sprites.portal_texture, game.sprites.portal_atlas);
            }
        }
    }
}

fn killPlayer(game: *Game) void {
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

fn playerWin(game: *Game) void {
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

fn killEnemy(game: *Game, entity: entt.Entity) void {
    game.playSound(game.sounds.hit);

    const reg = game.reg;

    const enemy = reg.get(comp.Enemy, entity);
    const score_info = switch (enemy.type) {
        .slow => ScoreInfo{ .text = FloatingText.score_10, .value = 10 },
        .fast => ScoreInfo{ .text = FloatingText.score_20, .value = 20 },
    };
    game.updateScore(score_info.value);
    const pos = reg.get(comp.Position, entity);
    _ = prefabs.createFloatingText(game.reg, pos.toVec2(), score_info.text);

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

fn pickupItem(game: *Game, entity: entt.Entity) void {
    const ItemInfo = struct {
        score: ScoreInfo,
        sound: rl.Sound,
    };
    const item = game.reg.getConst(comp.Item, entity);
    const item_info = switch (item.type) {
        .coin => ItemInfo{
            .score = ScoreInfo{ .text = FloatingText.score_20, .value = 20 },
            .sound = game.sounds.pickup_coin,
        },
    };
    game.playSound(item_info.sound);
    game.updateScore(item_info.score.value);
    const pos = game.reg.getConst(comp.Position, entity);
    _ = prefabs.createFloatingText(game.reg, pos.toVec2(), item_info.score.text);
    game.reg.destroy(entity);
}

fn updateEnemies(game: *Game) void {
    const reg = game.reg;
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
    game: *Game,
    collision_system: *systems.collision.CollisionSystem,
    delta_time: f32,
) void {
    const reg = game.reg;
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
            if (use_entity_specific_response and game.next_state != .lost) {
                if (collide_with_enemy) {
                    const kill_enemy_normal: f32 = if (collider_is_player) 1 else -1;
                    if (result.normal.y() == kill_enemy_normal) {
                        const enemy_entity = if (entity_is_enemy) collision.entity else collision.collider;
                        killEnemy(game, enemy_entity);
                        // Make player bounce off the top of the enemy.
                        const player = game.entities.getPlayer();
                        const player_speed = reg.get(comp.Speed, player);
                        const player_vel = reg.get(comp.Velocity, player);
                        player_vel.value.yMut().* = -player_speed.value.y() * 0.5;
                    } else {
                        killPlayer(game);
                    }
                } else if (collide_deadly) {
                    killPlayer(game);
                } else if (collide_item) {
                    pickupItem(game, collision.collider);
                } else if (collide_goal) {
                    playerWin(game);
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

fn drawHud(game: *Game) void {
    const font = rl.getFontDefault() catch unreachable;
    const font_size = 20;
    const text_spacing = 2;
    const symbol_scale = 3;
    const padding = 10;
    var offset: i32 = padding;

    const ally = game.app.allocator;

    // Draw lives.
    {
        const symbol_size: i32 = @intCast(game.sprites.ui_heart.width);
        const symbols_width = @as(i32, @intCast(game.lives)) * symbol_size * symbol_scale;
        for (0..game.lives) |i| {
            const index: i32 = @intCast(i);
            const offset_x = rl.getScreenWidth() - offset - symbols_width + index * symbol_size * symbol_scale;
            game.sprites.ui_heart.drawEx(
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
        const symbol_size: i32 = @intCast(game.sprites.ui_coin.width);
        const offset_x = rl.getScreenWidth() - padding - symbol_size * symbol_scale;
        game.sprites.ui_coin.drawEx(
            rl.Vector2.init(@floatFromInt(offset_x), @floatFromInt(offset + padding)),
            0,
            symbol_scale,
            rl.Color.ray_white,
        );

        // Draw score text.
        {
            const text = std.fmt.allocPrintZ(ally, "{d}", .{game.score}) catch unreachable;
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
            .{game.level_time - game.level_timer.state},
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

    switch (game.state) {
        .playing => {},
        .paused => graphics.text.drawSymbolAndTextCenteredHorizontally(
            "PAUSED",
            padding,
            font,
            font_size,
            text_spacing,
            padding,
            game.sprites.ui_pause,
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
