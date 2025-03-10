const rl = @import("raylib");
const m = @import("../math/mod.zig");
const u = @import("../utils/mod.zig");

/// Update the camera to follow the target if a certain threshold is reached.
pub fn updateCameraTarget(camera: *rl.Camera2D, target: m.Vec2, threshold: m.Vec2) void {
    const display = m.Vec2.new(
        @as(f32, @floatFromInt(rl.getRenderWidth())),
        @as(f32, @floatFromInt(rl.getRenderHeight())),
    );

    // Update camera offset.
    const camera_offset = m.Vec2.one().sub(threshold).scale(0.5).mul(display);
    camera.offset = u.rl.vec2(camera_offset);

    // Update camera target.
    const world_min = rl.getScreenToWorld2D(u.rl.vec2(m.Vec2.one().sub(threshold).scale(0.5).mul(display)), camera.*);
    const world_max = rl.getScreenToWorld2D(u.rl.vec2(m.Vec2.one().add(threshold).scale(0.5).mul(display)), camera.*);
    if (target.x() < world_min.x) camera.target.x = target.x();
    if (target.y() < world_min.y) camera.target.y = target.y();
    if (target.x() > world_max.x) camera.target.x = world_min.x + (target.x() - world_max.x);
    if (target.y() > world_max.y) camera.target.y = world_min.y + (target.y() - world_max.y);
}

/// Get the optimal camera zoom for HiDPI displays.
pub fn getCameraZoom() f32 {
    const render_width: f32 = @floatFromInt(rl.getRenderWidth());
    const screen_width: f32 = @floatFromInt(rl.getScreenWidth());
    return render_width / screen_width;
}
