const Application = @import("../application.zig").Application;
const MainMenuScene = @import("./MainMenuScene.zig");
const GameScene = @import("./GameScene.zig").GameScene;
const GameMenuScene = @import("./GameMenuScene.zig");

pub const SceneContext = struct {
    app: *Application,
    main_menu_scene: *MainMenuScene,
    game_scene: *GameScene,
    game_menu_scene: *GameMenuScene,
};
