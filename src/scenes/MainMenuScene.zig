const rl = @import("raylib");
const SceneManager = @import("scene_manager.zig").SceneManager;
const Menu = @import("../Menu.zig");
const graphics = @import("../graphics/mod.zig");
const styles = @import("styles.zig");

const Action = enum(u32) {
    new_game = 1,
    quit = 2,

    pub fn value(self: Action) u32 {
        return @intFromEnum(self);
    }
};

const menu_items = [_]Menu.MenuItem{
    .{ .id = Action.new_game.value(), .label = "New Game" },
    .{ .id = Action.quit.value(), .label = "Quit" },
};

const Self = @This();
pub const init = Self{};

menu: Menu = undefined,

pub fn scene(self: *Self) SceneManager.Scene {
    return .{
        .ptr = self,
        .vtable = &.{
            .init = init_fn,
            .update = update,
            .render = render,
        },
    };
}

fn init_fn(ptr: *anyopaque, _: SceneManager.Context) !void {
    const self = SceneManager.ptrCast(Self, ptr);
    self.menu = try Menu.new(
        &menu_items,
        styles.menu_options,
    );
}

fn update(ptr: *anyopaque, ctx: SceneManager.Context, _: f32) !void {
    const self = SceneManager.ptrCast(Self, ptr);

    if (rl.isKeyPressed(rl.KeyboardKey.escape) or rl.isKeyPressed(rl.KeyboardKey.q)) {
        ctx.context.app.shutdown();
    }

    if (rl.isKeyPressed(rl.KeyboardKey.enter)) {
        switch (self.menu.currentItem().id) {
            Action.new_game.value() => try ctx.manager.push(ctx.context.game_scene.scene()),
            Action.quit.value() => ctx.context.app.shutdown(),
            else => unreachable,
        }
    }

    if (rl.isKeyReleased(rl.KeyboardKey.up) or rl.isKeyReleased(rl.KeyboardKey.k)) {
        self.menu.previous();
    }
    if (rl.isKeyReleased(rl.KeyboardKey.down) or rl.isKeyReleased(rl.KeyboardKey.j)) {
        self.menu.next();
    }
}

fn render(ptr: *anyopaque) void {
    const self = SceneManager.ptrCast(Self, ptr);
    rl.clearBackground(rl.Color.fromInt(styles.background.color));
    self.menu.render();
}
