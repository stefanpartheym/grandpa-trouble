const Application = @import("../Application.zig");
const MainMenuScene = @import("./MainMenuScene.zig");
const GameScene = @import("./GameScene.zig");
const GameMenuScene = @import("./GameMenuScene.zig");

app: *Application,
main_menu_scene: *MainMenuScene,
game_scene: *GameScene,
game_menu_scene: *GameMenuScene,
