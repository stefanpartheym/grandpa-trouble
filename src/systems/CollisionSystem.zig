const std = @import("std");
const entt = @import("entt");
const m = @import("../math/mod.zig");
const coll = @import("../collision.zig");

const Self = @This();

ally: std.mem.Allocator,
/// Queue of collisions that occurred in the current frame. Collisions are
/// processed in order.
/// The queue is cleared on each frame.
queue: CollisionQueue,
/// List of collisions for the entity that is currently being processed.
/// This buffer is cleared on each iteration of the entity collision
/// detection.
buffer: CollisionList,

pub fn init(ally: std.mem.Allocator) Self {
    return .{
        .ally = ally,
        .queue = CollisionQueue.init(ally),
        .buffer = CollisionList.init(ally),
    };
}

pub fn deinit(self: *Self) void {
    self.queue.deinit();
    self.buffer.deinit();
}

/// Sort collisions by time to resolve nearest collision first.
pub fn sortBuffer(self: *Self) void {
    const sort = struct {
        /// Compare function to sort collision results by time.
        pub fn sortFn(_: void, lhs: CollisionData, rhs: CollisionData) bool {
            return lhs.result.time < rhs.result.time;
        }
    }.sortFn;
    std.sort.insertion(CollisionData, self.buffer.items, {}, sort);
}

/// This function is intended to be called on each frame before performing
/// collision detection and resolution.
pub fn resetQueue(self: *Self) void {
    self.queue.clear();
}

/// This function is intended to be called before detecting collisions for
/// a single entity.
pub fn resetBuffer(self: *Self) void {
    self.buffer.clearAndFree();
}

const CollisionList = std.ArrayList(CollisionData);

const CollisionQueue = struct {
    const CollisionMap = std.AutoHashMap(EntityPairHash, void);

    list: CollisionList,
    map: CollisionMap,

    pub fn init(alloc: std.mem.Allocator) @This() {
        return .{
            .list = CollisionList.init(alloc),
            .map = CollisionMap.init(alloc),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.list.deinit();
        self.map.deinit();
    }

    pub fn clear(self: *@This()) void {
        self.list.clearAndFree();
        self.map.clearAndFree();
    }

    pub fn items(self: @This()) []CollisionData {
        return self.list.items;
    }

    pub fn contains(self: *@This(), hash: EntityPairHash) bool {
        return self.map.contains(hash);
    }

    pub fn append(self: *@This(), data: CollisionData) !void {
        try self.list.append(data);
        try self.map.put(data.hash(), {});
    }
};

pub const CollisionData = struct {
    const Self = @This();

    entity: entt.Entity,
    entity_aabb: coll.Aabb,
    collider: entt.Entity,
    collider_aabb: coll.Aabb,
    collider_vel: m.Vec2,
    result: coll.CollisionResult,

    pub fn new(
        entity: entt.Entity,
        entity_aabb: coll.Aabb,
        collider: entt.Entity,
        collider_aabb: coll.Aabb,
        collider_vel: m.Vec2,
        result: coll.CollisionResult,
    ) @This() {
        return .{
            .entity = entity,
            .entity_aabb = entity_aabb,
            .collider = collider,
            .collider_aabb = collider_aabb,
            .collider_vel = collider_vel,
            .result = result,
        };
    }

    pub fn hash(self: @This()) EntityPairHash {
        return entity_pair_hash(self.entity, self.collider);
    }
};

const EntityPairHash = u128;

/// Generate a hash based on two entity IDs.
/// The smaller entity ID is always put in the lower 64 bits. This will
/// generate the same hash regardless of the order in which the IDs are
/// provided.
fn entity_pair_hash(entity1: entt.Entity, entity2: entt.Entity) EntityPairHash {
    return if (entity1 < entity2)
        @as(EntityPairHash, @intCast(entity1)) << 64 | @as(EntityPairHash, @intCast(entity2))
    else
        @as(EntityPairHash, @intCast(entity2)) << 64 | @as(EntityPairHash, @intCast(entity1));
}

//------------------------------------------------------------------------------
// Tests
//------------------------------------------------------------------------------

test "entity_pair_hash: should generate same hash regardless of order of arguments" {
    const expected_hash = 0x00000000000000010000000000000002;
    const collision_hash1 = entity_pair_hash(1, 2);
    try std.testing.expectEqual(expected_hash, collision_hash1);
    const collision_hash2 = entity_pair_hash(2, 1);
    try std.testing.expectEqual(expected_hash, collision_hash2);
}

test "entity_pair_hash: should generate hash for entity ID with max u32" {
    const entity1: entt.Entity = std.math.maxInt(u32);
    const entity2: entt.Entity = 0x123456;
    const expected_hash = 0x000000000012345600000000FFFFFFFF;
    const collision_hash1 = entity_pair_hash(entity1, entity2);
    try std.testing.expectEqual(expected_hash, collision_hash1);
    const collision_hash2 = entity_pair_hash(entity2, entity1);
    try std.testing.expectEqual(expected_hash, collision_hash2);
}
