const rl = @import("raylib");
const paa = @import("paa.zig");
const application = @import("application.zig");
const scenes = @import("scenes/mod.zig");

pub fn main() !void {
    var alloc = paa.init();
    defer alloc.deinit();

    var app = application.Application.init(
        alloc.allocator(),
        application.ApplicationConfig{
            .title = "Grandpa Trouble",
            .display = .{
                .width = 960,
                .height = 640,
                .high_dpi = true,
                .target_fps = 60,
            },
        },
    );
    defer app.deinit();

    // Setup scenes.
    var main_menu_scene = scenes.MainMenuScene.init;
    var game_scene = scenes.GameScene.init;
    var game_menu_scene = scenes.GameMenuScene.init;

    var scene_manager = scenes.SceneManager.init(
        alloc.allocator(),
        .{
            .app = &app,
            .main_menu_scene = &main_menu_scene,
            .game_scene = &game_scene,
            .game_menu_scene = &game_menu_scene,
        },
    );
    defer scene_manager.deinit();

    // Start application.
    // Must happen before loading textures and sounds.
    app.start();
    // Do not exit the application when Escape key is pressed.
    rl.setExitKey(rl.KeyboardKey.null);

    try scene_manager.push(main_menu_scene.scene());

    while (app.isRunning()) {
        if (rl.windowShouldClose()) {
            app.shutdown();
        }
        try scene_manager.update(rl.getFrameTime());
        rl.beginDrawing();
        scene_manager.render();
        rl.endDrawing();
    }
}
