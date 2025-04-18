const rl = @import("raylib");
const SceneManager = @import("scene_manager.zig").SceneManager;
const graphics = @import("../graphics/mod.zig");
const styles = @import("styles.zig");

const Self = @This();
pub const init = Self{};

pub fn scene(self: *Self) SceneManager.Scene {
    return .{
        .ptr = self,
        .vtable = &.{
            .update = update,
            .render = render,
        },
    };
}

fn update(_: *anyopaque, ctx: SceneManager.Context, _: f32) !void {
    if (rl.isKeyPressed(rl.KeyboardKey.escape) or rl.isKeyPressed(rl.KeyboardKey.q)) {
        ctx.context.app.shutdown();
    }
    if (rl.isKeyPressed(rl.KeyboardKey.enter)) {
        try ctx.manager.push(ctx.context.game_scene.scene());
    }
}

fn render(_: *anyopaque) void {
    rl.clearBackground(rl.Color.fromInt(styles.background.color));
    const offset_y = 260;
    graphics.text.drawTextCenteredH(
        "[ENTER] Start game",
        styles.menu_text.size,
        rl.Color.fromInt(styles.menu_text.color.regular),
        offset_y,
    );
    graphics.text.drawTextCenteredH(
        "[ESC] Quit",
        styles.menu_text.size,
        rl.Color.fromInt(styles.menu_text.color.regular),
        offset_y + styles.menu_text.size + 10,
    );
}
