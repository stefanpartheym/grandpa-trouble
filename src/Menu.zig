const std = @import("std");
const rl = @import("raylib");

pub const MenuItem = struct {
    id: u32,
    label: [:0]const u8,
};

pub const Options = struct {
    const default_font_size = 36;

    /// Index of the item selected initially.
    initial_index: usize = 0,

    /// Minimum width of the menu.
    min_width: f32 = 300,
    menu_padding: f32 = 60,
    menu_color: rl.Color = rl.Color.black,

    /// Space between items.
    item_spacing: f32 = 10,
    item_padding: f32 = 10,
    item_color: rl.Color = rl.Color.dark_gray,

    font: ?rl.Font = null,
    font_size: f32 = default_font_size,
    /// Space between characters.
    text_spacing: f32 = default_font_size / 10,
    text_color_regular: rl.Color = rl.Color.gray,
    text_color_selected: rl.Color = rl.Color.ray_white,
};

const Self = @This();

items: []const MenuItem,
index: usize,

min_width: f32,
menu_padding: f32,
menu_color: rl.Color,

item_spacing: f32,
item_padding: f32,
item_color: rl.Color,

font: rl.Font,
font_size: f32,
text_spacing: f32,
text_color_regular: rl.Color,
text_color_selected: rl.Color,

pub fn new(items: []const MenuItem, options: Options) !Self {
    return Self{
        .items = items,
        .index = options.initial_index,
        .min_width = options.min_width,
        .menu_padding = options.menu_padding,
        .menu_color = options.menu_color,
        .item_spacing = options.item_spacing,
        .item_padding = options.item_padding,
        .item_color = options.item_color,
        .font = options.font orelse try rl.getFontDefault(),
        .font_size = options.font_size,
        .text_spacing = options.text_spacing,
        .text_color_regular = options.text_color_regular,
        .text_color_selected = options.text_color_selected,
    };
}

pub fn render(self: Self) void {
    const screen_size = rl.Vector2.init(
        @floatFromInt(rl.getScreenWidth()),
        @floatFromInt(rl.getScreenHeight()),
    );
    const item_size = rl.Vector2.init(self.getItemMaxWidth(), self.getItemHeight());
    const menu_size = self.getSize(item_size.x);
    const menu_offset = screen_size.subtract(menu_size).scale(0.5);
    rl.drawRectangleV(menu_offset, menu_size, self.menu_color);

    for (self.items, 0..) |item, i| {
        const index: f32 = @floatFromInt(i);
        const item_pos = menu_offset.add(rl.Vector2.init(
            self.menu_padding,
            self.menu_padding + index * (item_size.y + self.item_spacing),
        ));
        const item_text_width = self.getItemTextWidth(item);
        const item_text_pos = item_pos.add(rl.Vector2.init((item_size.x - item_text_width) / 2, self.item_padding));
        rl.drawRectangleV(item_pos, item_size, self.item_color);
        rl.drawTextEx(
            self.font,
            item.label,
            item_text_pos,
            self.font_size,
            self.text_spacing,
            if (i == self.index) self.text_color_selected else self.text_color_regular,
        );
    }
}

pub fn currentItem(self: *Self) MenuItem {
    return self.items[self.index];
}

pub fn next(self: *Self) void {
    if (self.index < self.items.len - 1) {
        self.index += 1;
    }
}

pub fn previous(self: *Self) void {
    if (self.index > 0) {
        self.index -= 1;
    }
}

fn getSize(self: Self, item_max_width: f32) rl.Vector2 {
    const padding = self.menu_padding * 2;
    const item_count: f32 = @floatFromInt(self.items.len);
    const height = item_count * self.getItemHeight() + self.item_spacing * (item_count - 1) + padding;
    const width = item_max_width + padding;
    return rl.Vector2.init(width, height);
}

fn getItemWidth(self: Self, item: MenuItem) f32 {
    return self.getItemTextWidth(item) + self.item_padding * 2;
}

fn getItemMaxWidth(self: Self) f32 {
    var width: f32 = 0;
    for (self.items) |item| {
        width = @max(width, self.getItemWidth(item));
    }
    return @max(width, self.min_width);
}

fn getItemHeight(self: Self) f32 {
    return self.font_size + self.item_padding * 2;
}

fn getItemTextWidth(self: Self, item: MenuItem) f32 {
    return rl.measureTextEx(self.font, item.label, self.font_size, self.text_spacing).x;
}
