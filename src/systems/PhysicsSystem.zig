const std = @import("std");
const entt = @import("entt");
const m = @import("../math/mod.zig");
const comp = @import("../components.zig");
const collutils = @import("../collision.zig");
const CollisionSystem = @import("./CollisionSystem.zig");
const CollisionData = CollisionSystem.CollisionData;

const Self = @This();

reg: *entt.Registry,
collision_system: *CollisionSystem,
/// Entities to apply gravity to.
gravity_view: entt.MultiView(2, 1),
/// Entities to clamp velocity of.
velocity_view: entt.MultiView(1, 1),
/// Entities to check for collisions.
entity_view: entt.MultiView(3, 1),
/// Potential collider entities to check against.
collider_view: entt.MultiView(2, 0),

pub fn init(reg: *entt.Registry, collision_system: *CollisionSystem) Self {
    return .{
        .reg = reg,
        .collision_system = collision_system,
        .gravity_view = reg.view(.{ comp.Velocity, comp.Gravity }, .{comp.Disabled}),
        .velocity_view = reg.view(.{comp.Velocity}, .{comp.Disabled}),
        .entity_view = reg.view(.{ comp.Position, comp.Velocity, comp.Collision }, .{comp.Disabled}),
        .collider_view = reg.view(.{ comp.Position, comp.Collision }, .{}),
    };
}

pub fn deinit(self: *Self) void {
    _ = self;
}

pub fn update(self: *Self, delta_time: f32) !void {
    self.applyGravity(1980 * delta_time);
    self.clampVelocity();
    self.collision_system.resetQueue();
    try self.detectCollisions(delta_time);
}

/// Apply gravity to all relevant entities.
fn applyGravity(self: *Self, force: f32) void {
    var it = self.gravity_view.entityIterator();
    while (it.next()) |entity| {
        const gravity = self.gravity_view.get(comp.Gravity, entity);
        const gravity_amount = force * gravity.factor;
        var vel = self.gravity_view.get(comp.Velocity, entity);
        vel.value.yMut().* += gravity_amount;
    }
}

/// Clamp to terminal velocity.
fn clampVelocity(self: *Self) void {
    var it = self.velocity_view.entityIterator();
    while (it.next()) |entity| {
        var vel: *comp.Velocity = self.velocity_view.get(comp.Velocity, entity);
        const lower = vel.terminal.scale(-1);
        const upper = vel.terminal;
        const vel_clamped = m.Vec2.new(
            std.math.clamp(vel.value.x(), lower.x(), upper.x()),
            std.math.clamp(vel.value.y(), lower.y(), upper.y()),
        );
        vel.value = vel_clamped;
    }
}

fn detectCollisions(self: *Self, delta_time: f32) !void {
    var it = self.entity_view.entityIterator();
    var collider_it = self.collider_view.entityIterator();

    // Reset collision state for all dynamic entities.
    while (it.next()) |entity| {
        var collision = self.entity_view.get(comp.Collision, entity);
        collision.normal = m.Vec2.zero();
    }

    it.reset();

    // Perform collision detection.
    while (it.next()) |entity| {
        self.collision_system.resetBuffer();

        const pos = self.entity_view.get(comp.Position, entity);
        var collision_comp = self.entity_view.get(comp.Collision, entity);
        var vel = self.entity_view.get(comp.Velocity, entity);
        const aabb = collutils.Aabb.new(pos.toVec2(), collision_comp.aabb_size);
        const broadphase_aabb = collutils.Aabb.fromMovement(pos.toVec2(), collision_comp.aabb_size, vel.value.scale(delta_time));

        // Perform broadphase collision detection.
        // Do NOT exclude disabled entities for the colliders, as they would
        // otherwise be skipped in collision detection and entities would fall
        // through the gorund.
        collider_it.reset();
        while (collider_it.next()) |collider| {
            // Skip collision check with self.
            if (collider == entity) continue;

            // Skip collision check if entities cannot collide.
            const collider_collision_comp = self.collider_view.getConst(comp.Collision, collider);
            if (!collision_comp.canCollide(collider_collision_comp)) continue;

            const collider_pos = self.collider_view.get(comp.Position, collider).toVec2();
            const collider_size = collider_collision_comp.aabb_size;
            // Get collider velocity, if available.
            const collider_vel = if (self.reg.tryGet(comp.Velocity, collider)) |collider_vel_comp|
                collider_vel_comp.value
            else
                m.Vec2.zero();
            // Calculate broadphase collider AABB based on potential movement.
            const broadphase_collider_aabb = collutils.Aabb.fromMovement(
                collider_pos,
                collider_size,
                collider_vel.scale(delta_time),
            );
            // Check intersection between broadphase AABBs.
            if (broadphase_aabb.intersects(broadphase_collider_aabb)) {
                const collider_aabb = collutils.Aabb.new(collider_pos, collider_size);
                const relative_vel = vel.value.sub(collider_vel).scale(delta_time);
                // Calculate time of impact based on relative velocity.
                const result = collutils.aabbToAabb(aabb, collider_aabb, relative_vel);
                try self.collision_system.buffer.append(CollisionData.new(
                    entity,
                    aabb,
                    collider,
                    collider_aabb,
                    collider_vel,
                    result,
                ));
            }
        }

        // Sort collisions by time to resolve nearest collision first.
        self.collision_system.sortBuffer();

        // Append collisions in order.
        for (self.collision_system.buffer.items) |collision| {
            // Skip collisions, that are already in the list.
            if (!self.collision_system.queue.contains(collision.hash())) {
                try self.collision_system.queue.append(collision);
            }
        }
    }
}
