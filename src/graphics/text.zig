const rl = @import("raylib");

pub fn drawTextCenteredH(
    text: [:0]const u8,
    size: i32,
    color: rl.Color,
    pos_y: i32,
) void {
    const text_width = rl.measureText(text, size);
    rl.drawText(
        text,
        @divTrunc(rl.getScreenWidth(), 2) - @divTrunc(text_width, 2),
        pos_y,
        size,
        color,
    );
}

pub fn drawTextCentered(
    text: [:0]const u8,
    size: i32,
    color: rl.Color,
) void {
    const text_width = rl.measureText(text, size);
    rl.drawText(
        text,
        @divTrunc(rl.getScreenWidth(), 2) - @divTrunc(text_width, 2),
        @divTrunc(rl.getScreenHeight(), 2) - @divTrunc(size, 2),
        size,
        color,
    );
}

pub fn drawSymbolAndTextCenteredHorizontally(
    text: [:0]const u8,
    pos_y: f32,
    font: rl.Font,
    font_size: f32,
    spacing: f32,
    padding: f32,
    symbol_texture: *const rl.Texture,
    symbol_scale: f32,
) void {
    const render_width: f32 = @floatFromInt(rl.getScreenWidth());
    const text_size = rl.measureTextEx(font, text, font_size, spacing);
    const symbol_size: f32 = @as(f32, @floatFromInt(symbol_texture.width)) * symbol_scale;
    const symbol_offset = render_width / 2 - (text_size.x + padding + symbol_size) / 2;

    symbol_texture.drawEx(
        rl.Vector2.init(symbol_offset, pos_y),
        0,
        symbol_scale,
        rl.Color.ray_white,
    );
    rl.drawTextEx(
        font,
        text,
        rl.Vector2.init(symbol_offset + symbol_size + padding, pos_y + symbol_size / 2 - text_size.y / 2),
        font_size,
        spacing,
        rl.Color.ray_white,
    );
}
