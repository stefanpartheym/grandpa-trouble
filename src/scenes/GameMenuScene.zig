const rl = @import("raylib");
const SceneManager = @import("./scene_manager.zig").SceneManager;
const Menu = @import("../Menu.zig");
const graphics = @import("../graphics/mod.zig");
const styles = @import("styles.zig");

const Action = enum(u32) {
    resume_game = 1,
    exit = 2,

    pub fn value(self: Action) u32 {
        return @intFromEnum(self);
    }
};

const menu_items = [_]Menu.MenuItem{
    .{ .id = Action.resume_game.value(), .label = "Resume" },
    .{ .id = Action.exit.value(), .label = "Exit" },
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

    if (rl.isKeyPressed(rl.KeyboardKey.enter)) {
        switch (self.menu.currentItem().id) {
            Action.resume_game.value() => ctx.manager.pop(),
            Action.exit.value() => try ctx.manager.replace(ctx.context.main_menu_scene.scene()),
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
