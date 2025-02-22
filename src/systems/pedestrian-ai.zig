const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const ecs = @import("ecs");
const zlm = @import("zlm");
const zge = @import("zge");

const util = @import("../util.zig");

const Textures = @import("../textures.zig").Textures;

const TextureComponent = @import("zge").components.TextureComponent;
const RigidBody = @import("zge").physics.RigidBody;
const AABB = @import("zge").physics.shape.AABB;
const PedestrianAI = @import("../components.zig").PedestrianAI;
const AnimationComponent = @import("../components.zig").AnimationComponent;
const PhysicsSystem = zge.physics.PhysicsSystem;
const V = zge.vector.V;
const Vector = zge.vector.Vector;

const AVOIDANCE_RADIUS = 64;
const AVOID_PLAYER_THRESHOLD_VELOCITY = 10000;

pub const PedestrianAISystem = struct {
    pub fn update(
        allocator: Allocator,
        reg: *ecs.Registry,
        physicsSystem: *PhysicsSystem,
        player: ecs.Entity,
        textures: *const Textures(rl.Texture2D),
        t: f64,
    ) void {
        avoidPlayerCar(allocator, reg, physicsSystem, player, t);
        updateStates(reg, textures, t);
    }

    fn updateStates(
        reg: *ecs.Registry,
        textures: *const Textures(rl.Texture2D),
        t: f64,
    ) void {
        var view = reg.view(.{ PedestrianAI, RigidBody, AnimationComponent }, .{});
        var it = view.entityIterator();

        while (it.next()) |entity| {
            const ai = reg.get(PedestrianAI, entity);
            const body = reg.get(RigidBody, entity);
            const animation = reg.get(AnimationComponent, entity);

            updatePedestrianState(reg, ai, animation, body, entity, textures, t);
        }
    }

    fn updatePedestrianState(
        reg: *ecs.Registry,
        ai: *PedestrianAI,
        animation: *AnimationComponent,
        body: *RigidBody,
        entity: ecs.Entity,
        textures: *const Textures(rl.Texture2D),
        t: f64,
    ) void {
        const newState = ai.update(t);

        if (newState) |state| {
            switch (state) {
                .idle => {
                    updatePedestrianIdle(reg, animation, body, entity, textures);
                },
                .walking => |s| {
                    updatePedestrianWalking(animation, body, s);
                },
                // The way this is setup now, doesn't get in here but is handled in avoidPlayerCar
                .avoiding => |s| {
                    updatePedestrianAvoiding(animation, body, s);
                },
            }
        }
    }

    fn updatePedestrianIdle(
        reg: *ecs.Registry,
        animation: *AnimationComponent,
        body: *RigidBody,
        entity: ecs.Entity,
        textures: *const Textures(rl.Texture2D),
    ) void {
        reg.addOrReplace(entity, TextureComponent.init(&textures.pedestrianBlueIdle, null, V.zero));
        animation.animationInstance.pause();
        body.d.setVel(V.zero);
    }

    fn updatePedestrianWalking(
        animation: *AnimationComponent,
        body: *RigidBody,
        s: PedestrianAI.State.Moving,
    ) void {
        body.d.setVel(V.init(
            std.math.cos(s.direction) * s.speed,
            std.math.sin(s.direction) * s.speed,
        ));
        animation.animationInstance.unPause();
    }

    fn updatePedestrianAvoiding(
        animation: *AnimationComponent,
        body: *RigidBody,
        s: PedestrianAI.State.Avoiding,
    ) void {
        body.d.setVel(s.velocity);
        animation.animationInstance.unPause();
    }

    fn getPlayerVel(reg: *ecs.Registry, player: ecs.Entity) Vector {
        const playerBody = reg.get(RigidBody, player);
        const playerVel = playerBody.d.cloneVel();

        return playerVel;
    }

    fn getPlayerVelDir(reg: *ecs.Registry, player: ecs.Entity) Vector {
        return getPlayerVel(reg, player).normalize();
    }

    fn getBaseAvoidCarAABBScale() f32 {
        return if (rl.isKeyDown(rl.KeyboardKey.g)) 3 else 1;
    }

    pub fn getPedestrianAvoidCarAABB(
        reg: *ecs.Registry,
        player: ecs.Entity,
    ) AABB {
        const playerBody = reg.get(RigidBody, player);
        const playerVel = playerBody.d.cloneVel();

        if (V.length2(playerVel) < AVOID_PLAYER_THRESHOLD_VELOCITY) {
            const scale = getBaseAvoidCarAABBScale() * 2;
            return playerBody.aabb.scale(scale);
        }

        return getPedestrianAvoidCarAABBX(playerBody, playerVel, V.normalize(playerVel));
    }

    fn getPedestrianAvoidCarAABBX(
        playerBody: *RigidBody,
        playerVel: Vector,
        playerVelDir: Vector,
    ) AABB {
        const playerR = playerBody.aabb.width();
        const scale = getBaseAvoidCarAABBScale() + 0.5;
        var avoidanceAABB = playerBody.aabb.add(playerVelDir * V.scalar(playerR)).scale(scale);
        avoidanceAABB = avoidanceAABB.expand(playerVel * V.scalar(0.005));

        return avoidanceAABB;
    }

    fn calculatePedestrianAvoidanceJump(
        reg: *ecs.Registry,
        player: ecs.Entity,
        body: *RigidBody,
    ) Vector {
        const playerBody = reg.get(RigidBody, player);
        const playerPos = playerBody.aabb.center();
        const playerVel = playerBody.d.cloneVel();
        const relative = body.aabb.center() - playerPos;

        const isBelowThreshold = V.length2(playerBody.d.cloneVel()) < AVOID_PLAYER_THRESHOLD_VELOCITY;
        const isBehindCar = V.dot(relative, playerVel) < 0;

        const minLength = 100;

        if (isBelowThreshold and isBehindCar) {
            return relative * V.scalar(0.5);
        }

        const playerVelPerp = V.rotate(playerVel, util.Direction.up);
        const perpDot = V.dot(relative, playerVelPerp);
        const avoidV = util.minLength(playerVelPerp * V.scalar(std.math.sign(perpDot)), minLength);

        return avoidV;
    }

    fn setPedestrianAIToAvoidPlayer(reg: *ecs.Registry, ai: *PedestrianAI, player: ecs.Entity, entity: ecs.Entity, t: f64) void {
        const body = reg.get(RigidBody, entity);
        const jumpV = calculatePedestrianAvoidanceJump(reg, player, body);

        ai.state = .{ .avoiding = .{
            .velocity = jumpV,
        } };
        ai.nextStateAt = PedestrianAI.JUMP_DURATION + t;

        const animation = reg.get(AnimationComponent, entity);

        reg.get(RigidBody, entity).d.setVel(jumpV);
        animation.animationInstance.unPause();
    }

    fn avoidPlayerCar(
        allocator: Allocator,
        reg: *ecs.Registry,
        physicsSystem: *PhysicsSystem,
        player: ecs.Entity,
        t: f64,
    ) void {
        const avoidanceAABB = getPedestrianAvoidCarAABB(reg, player);
        const intersections = physicsSystem.findIntersectionsRect(
            avoidanceAABB,
        );
        defer allocator.free(intersections);

        for (intersections) |intersection| {
            const entity = intersection.entry.key;
            const ai = reg.tryGet(PedestrianAI, entity);

            if (ai == null or ai.?.state == .avoiding) continue;

            setPedestrianAIToAvoidPlayer(reg, ai.?, player, entity, t);
        }
    }
};
