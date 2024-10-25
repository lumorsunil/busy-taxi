const std = @import("std");
const rl = @import("raylib");

const GameState = @import("../state-config.zig").GameState;

const components = @import("../components.zig");
const Transform = components.Transform;
const Physics = components.Physics;

pub const CollisionEvent = struct {
    entityA: usize,
    entityB: usize,
};

const MAX_COLLISION_EVENTS = 200;

pub const PhysicsSystem = struct {
    collisionEvents: [MAX_COLLISION_EVENTS]CollisionEvent = undefined,

    var numberOfCollisionEvent: usize = 0;

    pub fn update(self: *PhysicsSystem, s: *GameState, dt: f32) void {
        self.updatePositions(s, dt);
        self.updateCollisions(s);
    }

    fn updatePositions(_: *PhysicsSystem, s: *GameState, dt: f32) void {
        for (0..s.entities.len) |entity| {
            var transform = s.getComponent(Transform, entity) catch continue;
            var physics = s.getComponent(Physics, entity) catch continue;

            if (physics.isStatic) continue;

            physics.v.x += physics.a.x * dt;
            physics.v.y += physics.a.y * dt;

            physics.v.x -= physics.v.x * (1 - physics.f) * dt;
            physics.v.y -= physics.v.y * (1 - physics.f) * dt;

            transform.p.x += physics.v.x * dt;
            transform.p.y += physics.v.y * dt;
        }
    }

    fn updateCollisions(self: *PhysicsSystem, s: *GameState) void {
        for (0..s.entities.len) |entityA| {
            const transformA = s.getComponent(Transform, entityA) catch continue;
            const physicsA = s.getComponent(Physics, entityA) catch continue;

            const rectangleA0 = getPhysicalRect(physicsA, transformA);
            const rectangleA = PhysicalRect.fromComponents(physicsA, transformA);

            for (0..s.entities.len) |entityB| {
                if (entityA == entityB) continue;

                const transformB = s.getComponent(Transform, entityB) catch continue;
                const physicsB = s.getComponent(Physics, entityB) catch continue;

                const rectangleB0 = getPhysicalRect(physicsB, transformB);
                const rectangleB = PhysicalRect.fromComponents(physicsB, transformB);

                const a = rl.checkCollisionRecs(rectangleA0, rectangleB0);
                const b = rectangleA.checkCollision(rectangleB);

                _ = b;

                if (a) {
                    //if (b) {
                    const event = CollisionEvent{ .entityA = entityA, .entityB = entityB };
                    self.emitCollisionEvent(event);
                    self.handleCollision(physicsA, transformA, physicsB, transformB);
                }
            }
        }
    }

    fn emitCollisionEvent(self: *PhysicsSystem, event: CollisionEvent) void {
        self.collisionEvents[numberOfCollisionEvent] = event;
        numberOfCollisionEvent += 1;
    }

    fn handleCollision(self: *PhysicsSystem, physicsA: *Physics, transformA: *Transform, physicsB: *Physics, transformB: *Transform) void {
        if (physicsA.isSolid and physicsB.isSolid) {
            self.handleSolidCollision(physicsA, transformA, physicsB, transformB);
        }
    }

    fn handleSolidCollision(self: *PhysicsSystem, physicsA: *Physics, transformA: *Transform, physicsB: *Physics, transformB: *Transform) void {
        if (physicsA.isStatic and physicsB.isStatic) {
            return;
        } else if (physicsA.isStatic) {
            self.handleStaticCollision(physicsA, transformA, physicsB, transformB);
        } else if (physicsB.isStatic) {
            self.handleStaticCollision(physicsB, transformB, physicsA, transformA);
        }
    }

    pub const PhysicalRect = struct {
        l: f32,
        r: f32,
        t: f32,
        b: f32,
        w: f32,
        h: f32,

        pub fn checkCollision(self: PhysicalRect, other: PhysicalRect) bool {
            return (self.l <= other.r and other.l <= self.r and self.t <= other.b and other.t <= self.b);
        }

        pub fn fromComponents(physics: *Physics, transform: *Transform) PhysicalRect {
            const s = transform.s;
            const w = physics.cr.width * s;
            const h = physics.cr.height * s;
            const l = transform.p.x + physics.cr.x * s;
            const t = transform.p.y + physics.cr.y * s;

            return .{ .l = l, .t = t, .r = l + w, .b = t + h, .w = w, .h = h };
        }
    };

    pub inline fn getPhysicalRect(physics: *const Physics, transform: *const Transform) rl.Rectangle {
        const s = transform.s;
        const w = physics.cr.width * s;
        const h = physics.cr.height * s;
        const x = transform.p.x + physics.cr.x * s;
        const y = transform.p.y + physics.cr.y * s;

        return rl.Rectangle.init(x, y, w, h);
    }

    fn handleStaticCollision(_: *PhysicsSystem, physicsStatic: *Physics, transformStatic: *Transform, physicsOther: *Physics, transformOther: *Transform) void {
        const staticRect = PhysicalRect.fromComponents(physicsStatic, transformStatic);
        const otherRect = PhysicalRect.fromComponents(physicsOther, transformOther);

        const ovx = physicsOther.v.x;
        const ovy = physicsOther.v.y;

        const ol = otherRect.l;
        const ot = otherRect.t;
        const ori = otherRect.r;
        const ob = otherRect.b;
        const sl = staticRect.l;
        const st = staticRect.t;
        const sr = staticRect.r;
        const sb = staticRect.b;

        const ctx = if (ovx > 0) ((ori - sl) / (ovx)) else if (ovx < 0) ((sr - ol) / (-ovx)) else std.math.inf(f32);
        const cty = if (ovy > 0) ((ob - st) / (ovy)) else if (ovy < 0) ((sb - ot) / (-ovy)) else std.math.inf(f32);

        const ct = @min(ctx, cty);

        const cvx = ovx * ct;
        const cvy = ovy * ct;

        transformOther.p.x -= (cvx * 2);
        transformOther.p.y -= (cvy * 2);

        if (ctx > cty) physicsOther.v.y = 0 else physicsOther.v.x = 0;
    }

    pub fn pollCollisions(self: *PhysicsSystem, comptime T: type, context: *T, onEvent: fn (context: *T, collisionEvent: CollisionEvent) void) void {
        for (0..numberOfCollisionEvent) |i| {
            onEvent(context, self.collisionEvents[i]);
        }

        numberOfCollisionEvent = 0;
    }
};
