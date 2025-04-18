const rl = @import("raylib");
const MenuOptions = @import("../Menu.zig").Options;

pub const background = struct {
    pub const color = 0x2a2520ff;
};

pub const menu_options = MenuOptions{
    .font_size = 36,
    .menu_color = rl.Color{ .r = 0x11, .g = 0x0e, .b = 0x0b, .a = 127 },
};
