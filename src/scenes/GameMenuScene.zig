const rl = @import("raylib");
const graphics = @import("../graphics/mod.zig");
const SceneManager = @import("./scene_manager.zig").SceneManager;
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
    if (rl.isKeyPressed(rl.KeyboardKey.enter)) {
        ctx.manager.pop();
    }
    if (rl.isKeyPressed(rl.KeyboardKey.escape) or rl.isKeyPressed(rl.KeyboardKey.q)) {
        try ctx.manager.replace(ctx.context.main_menu_scene.scene());
    }
}

fn render(_: *anyopaque) void {
    rl.clearBackground(rl.Color.fromInt(styles.background.color));
    const offset_y = 260;
    graphics.text.drawTextCenteredH(
        "[ENTER] Resume",
        styles.menu_text.size,
        rl.Color.fromInt(styles.menu_text.color.regular),
        offset_y,
    );
    graphics.text.drawTextCenteredH(
        "[ESC] Return to main menu",
        styles.menu_text.size,
        rl.Color.fromInt(styles.menu_text.color.regular),
        offset_y + styles.menu_text.size + 10,
    );
}
