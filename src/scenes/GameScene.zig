const std = @import("std");
const rl = @import("raylib");
const entt = @import("entt");
const u = @import("../utils/mod.zig");
const graphics = @import("../graphics/mod.zig");
const SceneManager = @import("./scene_manager.zig").SceneManager;
const Game = @import("../Game.zig");
const tiled = @import("../tiled.zig");
const ecs_systems = @import("../systems.zig");

const Self = @This();
pub const init = Self{
    .initialized = false,
    .allocator = undefined,
    .reg = undefined,
    .game = undefined,
    .camera = undefined,
    .resources = .{
        .tilemap = undefined,
        .sprites = undefined,
        .sounds = undefined,
    },
    .systems = undefined,
};

initialized: bool,
allocator: std.mem.Allocator,
reg: entt.Registry,
game: Game,
camera: rl.Camera2D,
resources: struct {
    tilemap: tiled.Tilemap,
    sprites: Game.Sprites,
    sounds: Game.Sounds,

    pub fn deinit(self: *@This()) void {
        self.sounds.deinit();
        self.sprites.deinit();
        self.tilemap.deinit();
    }
},
systems: Game.Systems,

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

    self.allocator = ctx.manager.allocator;
    self.reg = entt.Registry.init(self.allocator);
    errdefer self.reg.deinit();

    try self.loadResources();

    self.camera = rl.Camera2D{
        .target = .{ .x = 0, .y = 0 },
        .offset = .{ .x = 0, .y = 0 },
        .rotation = 0,
        .zoom = graphics.camera.getCameraZoom(),
    };

    self.game = Game.new(
        ctx.context.app,
        &self.reg,
        &self.systems,
        &self.resources.sprites,
        &self.resources.sounds,
        &self.resources.tilemap,
        &self.camera,
    );

    // Initialize systems
    self.systems = .{
        .collision = ecs_systems.CollisionSystem.init(self.allocator),
        .physics = ecs_systems.PhysicsSystem.init(&self.reg, &self.systems.collision),
        .render = ecs_systems.RenderSystem.init(&self.reg, &self.camera),
        .debug_render = ecs_systems.DebugRenderSystem.init(&self.reg, &self.camera, .{}),
        .animation = ecs_systems.AnimationSystem.init(&self.reg),
    };

    self.initialized = true;
    self.game.setState(.playing);
}

fn deinit(ptr: *anyopaque, _: std.mem.Allocator) void {
    const self = SceneManager.ptrCast(Self, ptr);
    self.systems.deinit();
    self.resources.deinit();
    self.reg.deinit();
    self.initialized = false;
}

fn update(ptr: *anyopaque, ctx: SceneManager.Context, dt: f32) !void {
    const self = SceneManager.ptrCast(Self, ptr);

    if (rl.isKeyPressed(.escape) or rl.isKeyPressed(.q)) {
        try ctx.manager.push(ctx.context.game_menu_scene.scene());
    }

    // Loop soundtrack
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

    try self.game.update(dt);
}

fn render(ptr: *anyopaque) void {
    var self = SceneManager.ptrCast(Self, ptr);
    rl.clearBackground(rl.Color.fromInt(0x2a252000));
    self.game.render();
}

fn loadResources(self: *Self) !void {
    // Load tilemap
    self.resources.tilemap = try tiled.Tilemap.fromFile(self.allocator, "./assets/map/map.tmj");
    errdefer self.resources.tilemap.deinit();

    // Load sprites
    const AnimatedSpriteSheet = graphics.sprites.AnimatedSpriteSheet;
    const tileset = try self.resources.tilemap.getTileset(1);
    self.resources.sprites.tileset_texture = try u.rl.loadTexture(self.allocator, tileset.image_path);
    errdefer self.resources.sprites.tileset_texture.unload();
    self.resources.sprites.player_texture = try rl.loadTexture("./assets/player.atlas.png");
    errdefer self.resources.sprites.player_texture.unload();
    self.resources.sprites.player_atlas = try AnimatedSpriteSheet.initFromGrid(self.allocator, 3, 4, "player_");
    errdefer self.resources.sprites.player_atlas.deinit();
    self.resources.sprites.portal_texture = try rl.loadTexture("./assets/portal.atlas.png");
    errdefer self.resources.sprites.portal_texture.unload();
    self.resources.sprites.portal_atlas = try AnimatedSpriteSheet.initFromGrid(self.allocator, 2, 3, "portal_");
    errdefer self.resources.sprites.portal_atlas.deinit();
    self.resources.sprites.enemies_texture = try rl.loadTexture("./assets/enemies.atlas.png");
    errdefer self.resources.sprites.enemies_texture.unload();
    self.resources.sprites.enemies_atlas = try AnimatedSpriteSheet.initFromGrid(self.allocator, 12, 2, "enemies_");
    errdefer self.resources.sprites.enemies_atlas.deinit();
    self.resources.sprites.coin_texture = try rl.loadTexture("./assets/coin.atlas.png");
    errdefer self.resources.sprites.coin_texture.unload();
    self.resources.sprites.coin_atlas = try AnimatedSpriteSheet.initFromGrid(self.allocator, 1, 8, "coin_");
    errdefer self.resources.sprites.coin_atlas.deinit();

    // Load Backgrounds
    self.resources.sprites.background_layer_1_texture = try rl.loadTexture("./assets/map/background_layer_1.png");
    errdefer self.resources.sprites.background_layer_1_texture.unload();
    self.resources.sprites.background_layer_2_texture = try rl.loadTexture("./assets/map/background_layer_2.png");
    errdefer self.resources.sprites.background_layer_2_texture.unload();
    self.resources.sprites.background_layer_3_texture = try rl.loadTexture("./assets/map/background_layer_3.png");
    errdefer self.resources.sprites.background_layer_3_texture.unload();

    // Load UI sprites
    self.resources.sprites.ui_pause = try rl.loadTexture("./assets/ui/pause_noborder_white.png");
    errdefer self.resources.sprites.ui_pause.unload();
    self.resources.sprites.ui_heart = try rl.loadTexture("./assets/ui/heart_shaded.png");
    errdefer self.resources.sprites.ui_heart.unload();
    self.resources.sprites.ui_coin = try rl.loadTexture("./assets/ui/coin_shaded.png");
    errdefer self.resources.sprites.ui_coin.unload();

    // Load sounds
    self.resources.sounds.soundtrack = try rl.loadMusicStream("./assets/soundtrack.wav");
    errdefer rl.unloadMusicStream(self.resources.sounds.soundtrack);
    self.resources.sounds.jump = try rl.loadSound("./assets/sounds/jump.wav");
    errdefer rl.unloadSound(self.resources.sounds.jump);
    self.resources.sounds.hit = try rl.loadSound("./assets/sounds/hit.wav");
    errdefer rl.unloadSound(self.resources.sounds.hit);
    self.resources.sounds.die = try rl.loadSound("./assets/sounds/die.wav");
    errdefer rl.unloadSound(self.resources.sounds.die);
    self.resources.sounds.portal = try rl.loadSound("./assets/sounds/portal.wav");
    errdefer rl.unloadSound(self.resources.sounds.portal);
    self.resources.sounds.pickup_coin = try rl.loadSound("./assets/sounds/pickup_coin.wav");
    errdefer rl.unloadSound(self.resources.sounds.pickup_coin);
}
