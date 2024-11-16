const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const rl = @import("raylib");

const cfg = @import("../config.zig");

const GameState = @import("../state-config.zig").GameState;

const components = @import("../components.zig");
const RigidBody = components.RigidBody;
const Collision = RigidBody.Collision;
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

    pub fn init() PhysicsSystem {
        return PhysicsSystem{};
    }

    pub fn update(self: *PhysicsSystem, s: *GameState, dt: f32) void {
        self.updatePositions(s, dt);
        self.updateCollisions(s);
    }

    fn updatePositions(_: *PhysicsSystem, s: *GameState, dt: f32) void {
        for (0..s.entities.len) |entity| {
            var rigidBody = s.getComponent(RigidBody, entity) catch continue;

            if (rigidBody.s.isStatic) continue;

            rigidBody.d.v = rigidBody.d.v.add(rigidBody.d.a.scale(dt));

            //physics.v.x -= physics.v.x * (1 - physics.f) * dt;
            //physics.v.y -= physics.v.y * (1 - physics.f) * dt;

            rigidBody.d.p = rigidBody.d.p.add(rigidBody.d.v.scale(dt));
        }
    }

    fn updatePositions0(_: *PhysicsSystem, s: *GameState, dt: f32) void {
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
        for (0..s.entities.len - 1) |entityA| {
            const rbA = s.getComponent(RigidBody, entityA) catch continue;

            for (entityA + 1..s.entities.len) |entityB| {
                const rbB = s.getComponent(RigidBody, entityB) catch continue;

                const result = rbA.checkCollision(rbB.*);

                switch (result) {
                    .collision => |collision| {
                        const event = CollisionEvent{ .entityA = entityA, .entityB = entityB };
                        self.emitCollisionEvent(event);
                        self.handleCollisionPhysics(rbA, rbB, collision);
                    },
                    .noCollision => continue,
                }
            }
        }
    }

    fn updateCollisions0(self: *PhysicsSystem, s: *GameState, dt: f32) void {
        for (0..s.entities.len - 1) |entityA| {
            const transformA = s.getComponent(Transform, entityA) catch continue;
            const physicsA = s.getComponent(Physics, entityA) catch continue;

            //const rectangleA0 = getPhysicalRect(physicsA, transformA);
            const rectangleA = PhysicalRect.fromComponents(physicsA, transformA);

            for (entityA + 1..s.entities.len) |entityB| {
                if (entityA == entityB) continue;

                const transformB = s.getComponent(Transform, entityB) catch continue;
                const physicsB = s.getComponent(Physics, entityB) catch continue;

                //const rectangleB0 = getPhysicalRect(physicsB, transformB);
                const rectangleB = PhysicalRect.fromComponents(physicsB, transformB);

                //const didCollide = rl.checkCollisionRecs(rectangleA0, rectangleB0);
                const didCollide = rectangleA.checkCollision(rectangleB);

                if (didCollide) {
                    const event = CollisionEvent{ .entityA = entityA, .entityB = entityB };
                    self.emitCollisionEvent(event);
                    self.handleCollisionPhysics(physicsA, transformA, physicsB, transformB, dt);
                }
            }
        }
    }

    fn emitCollisionEvent(self: *PhysicsSystem, event: CollisionEvent) void {
        self.collisionEvents[numberOfCollisionEvent] = event;
        numberOfCollisionEvent += 1;
    }

    fn handleCollision(self: *PhysicsSystem, physicsA: *Physics, transformA: *Transform, physicsB: *Physics, transformB: *Transform, dt: f32) void {
        if (physicsA.isSolid and physicsB.isSolid) {
            self.handleSolidCollision(physicsA, transformA, physicsB, transformB, dt);
        }
    }

    fn handleSolidCollision(self: *PhysicsSystem, physicsA: *Physics, transformA: *Transform, physicsB: *Physics, transformB: *Transform, dt: f32) void {
        if (physicsA.isStatic and physicsB.isStatic) {
            return;
        } else {
            self.handleCollisionPhysics(physicsA, transformA, physicsB, transformB, dt);
            //self.handleDynamicCollision(physicsA, transformA, physicsB, transformB);
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
            return ((self.l < other.r) and (other.l < self.r) and (self.t < other.b) and (other.t < self.b));
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

    fn handleCollisionPhysics(_: *PhysicsSystem, rbA: *RigidBody, rbB: *RigidBody, collision: Collision) void {
        RigidBody.resolveCollision(rbA, rbB, collision);
    }

    fn handleCollisionPhysics0(_: *PhysicsSystem, physicsA: *Physics, transformA: *Transform, physicsB: *Physics, transformB: *Transform, dt: f32) void {
        const rectA = PhysicalRect.fromComponents(physicsA, transformA);
        const rectB = PhysicalRect.fromComponents(physicsB, transformB);

        const vxa = physicsA.v.x;
        const vya = physicsA.v.y;
        const vxb = physicsB.v.x;
        const vyb = physicsB.v.y;

        const la = rectA.l - vxa * dt;
        const ta = rectA.t - vya * dt;
        const ra = rectA.r - vxa * dt;
        const ba = rectA.b - vya * dt;
        const lb = rectB.l - vxb * dt;
        const tb = rectB.t - vyb * dt;
        const rb = rectB.r - vxb * dt;
        const bb = rectB.b - vyb * dt;

        // ct = dt + (rb - la) / (vxa - vxb)
        // ct = dt + (ra - lb) / (vxb - vxa)

        const ctx0 = if ((vxa - vxb) != 0) ((rb - la) / (vxa - vxb)) else std.math.inf(f32);
        const ctx1 = if ((vxb - vxa) != 0) ((ra - lb) / (vxb - vxa)) else std.math.inf(f32);
        const ctx = @min(ctx0, ctx1);

        const cty0 = if ((vya - vyb) != 0) ((bb - ta) / (vya - vyb)) else std.math.inf(f32);
        const cty1 = if ((vyb - vya) != 0) ((ba - tb) / (vyb - vya)) else std.math.inf(f32);
        const cty = @min(cty0, cty1);

        const ct = @max(ctx, cty);

        if (ct > dt or ct <= 0) {
            std.log.err("\n\ninvalid ct value: {}, ctx: {}, cty: {}", .{ ct, ctx, cty });
            std.log.err("vxa {}, vya {}, la {}, ta {}, ra {}, ba {}", .{ vxa, vya, la, ta, ra, ba });
            std.log.err("vxb {}, vyb {}, lb {}, tb {}, rb {}, bb {}", .{ vxb, vyb, lb, tb, rb, bb });
            std.log.err("(rb - la) / (vxa - vxb) = ({} - {}) / ({} - {}) = ({}) / ({})", .{ rb, la, vxa, vxb, (rb - la), (vxa - vxb) });
            std.log.err("= {}", .{if ((vxa - vxb) != 0) (rb - la) / (vxa - vxb) else -std.math.inf(f32)});
            std.log.err("(ra - lb) / (vxb - vxa) = ({} - {}) / ({} - {}) = ({}) / ({})", .{ ra, lb, vxb, vxa, (lb - ra), (vxb - vxa) });
            std.log.err("= {}", .{if ((vxb - vxa) != 0) (ra - lb) / (vxb - vxa) else -std.math.inf(f32)});
            std.log.err("(bb - ta) / (vya - vyb) = ({} - {}) / ({} - {})", .{ bb, ta, vya, vyb });
            std.log.err("(ba - tb) / (vyb - vya) = ({} - {}) / ({} - {})", .{ ba, tb, vyb, vya });

            transformA.p.x += vxa * (-dt);
            transformA.p.y += vya * (-dt);

            transformB.p.x += vxb * (-dt);
            transformB.p.y += vyb * (-dt);

            return;
        }

        //const nonTouchingAdjustment = 0.5;
        //const act = ct * nonTouchingAdjustment;

        std.log.info("ct: {}, dt: {}", .{ ct, dt });

        transformA.p.x += vxa * (ct - dt);
        transformA.p.y += vya * (ct - dt);

        transformB.p.x += vxb * (ct - dt);
        transformB.p.y += vyb * (ct - dt);

        if (ctx > cty) {
            physicsB.v.y = 0;
            physicsA.v.y = 0;
        } else {
            physicsB.v.x = 0;
            physicsA.v.x = 0;
        }
    }

    //fn handleDynamicCollision(_: *PhysicsSystem, physicsA: *Physics, transformA: *Transform, physicsB: *Physics, transformB: *Transform) void {
    // (la + vxa * dt) <= (rb + vxb * dt)
    // (lb + vb * dt) <= (ra + va * dt)
    // (ta + vya * dt) <= (bb + vyb * dt)
    // (tb + vyb * dt) <= (ba + vya * dt)
    //
    //
    //
    //
    //
    //  (vxa < 0 and vxb >= 0) or (vxa < vxb): la + vxa * ct = rb + vxb * ct
    //  lb + vxb * ct = ra + vxa * ct
    //
    //
    //  a = .5 , b = .3 , va = -.5 , vb = .5
    //
    //  ct = (b - a) / (va - vb)
    //     = (.5 - .3) / (-.5 - .5)
    //     = .2 / -1
    //     = -.2
    //
    //  ct = (a - b) / (vb - va)
    //     = (.3 - .5) / (.5 - -.5)
    //     = -.2 / 1
    //     = -.2
    //
    //
    //
    //  la = 5 , rb = 3 , vxa = -.5 , vxb = .5
    //
    //  ctx = (rb - la) / (vxa - vxb)
    //      = (3 - 5) / (-.5 - .5)
    //      = -2 / -1
    //      = 2
    //
    //  ctx = (ra - lb) / (vxb - vxa)
    //      = (5 - 3) / (.5 - -.5)
    //      = 2 / 1
    //      = 2
    //
    //  ta = 4 , bb = 4 , vya = -.5 , vyb = .5
    //
    //  cty = (bb - ta) / (vya - vyb)
    //      = (4 - 4) / (-.5 - .5)
    //      = 0 / -1
    //      = 0
    //
    //  cty = (ba - tb) / (vyb - vya)
    //      = (4 - 4) / (.5 - -.5)
    //      = 0 / 1
    //      = 0
    //
    //
    //  la + ctx * vxa = rb + ctx * vxb
    //  5 + 2 * -.5 = 3 + 2 * .5
    //  5 + -1 = 3 + 1
    //  4 = 4
    //
    //
    //  ta + cty * vya = bb + cty * vyb
    //  4 + 0 * -.5 = 4 + 0 * .5
    //  4 + 0 = 4 + 0
    //  4 = 4
    //
    //
    //
    //
    // (la + vxa * dt) <= (rb + vxb * dt)
    // (lb + vxb * dt) <= (ra + vxa * dt)
    // 0 <= ct <= dt
    //
    // la + vxa * ct = rb + vxb * ct
    // lb + vxb * ct = ra + vxa * ct
    // 0 <= ct <= dt
    //
    //
    // (la + vxa * ctx) = (rb + vxb * ctx)
    // (lb + vxb * ctx) = (ra + vxa * ctx)
    // ctx = (rb - la) / (vxa - vxb)
    // ctx = (ra - lb) / (vxb - vxa)
    // 0 < ctx <= dt
    //
    // (ta + vya * cty) = (bb + vyb * cty)
    // (tb + vyb * cty) = (ba + vya * cty)
    // cty = (bb - ta) / (vya - vyb)
    // cty = (ba - tb) / (vyb - vya)
    // 0 < cty <= dt
    //
    // ct = max(ctx, cty)
    // 0 < ct <= dt
    //
    //
    //
    //
    //
    // la + vxa(ct - dt) = rb + vxb(ct - dt)
    // lb + vxb(ct - dt) = ra + vxa(ct - dt)
    //
    // ct = dt + (rb - la) / (vxa - vxb)
    // ct = dt + (ra - lb) / (vxb - vxa)
    // 0 < ct <= dt
    //
    //
    //
    //
    //
    //
    // (-la):        la + vxa * ct = rb + vxb * ct
    // (-vxb * ct):  vxa * ct = rb + vxb * ct - la
    // (factor):     vxa * ct - vxb * ct = rb - la
    // (/(vxa-vxb):  ct(vxa - vxb) = rb - la
    //               ct = (rb - la) / (vxa - vxb)
    //
    //
    // lb + vxb * ct = ra + vxa * ct
    // vxb * ct = ra + vxa * ct - lb
    // vxb * ct - vxa * ct = ra - lb
    // ct(vxb - vxa) = ra - lb
    // ct = (ra - lb) / (vxb - vxa)
    //
    //
    //
    // ct = (lb + wb - la) / (vxa - vxb)
    // ct = (la + wa - lb) / (vxb - vxa)
    //
    //
    //
    // xa = xa - ct * vxa
    //
    //}

    pub fn pollCollisions(self: *PhysicsSystem, comptime T: type, context: *T, onEvent: fn (context: *T, collisionEvent: CollisionEvent) void) void {
        for (0..numberOfCollisionEvent) |i| {
            onEvent(context, self.collisionEvents[i]);
        }

        numberOfCollisionEvent = 0;
    }
};
