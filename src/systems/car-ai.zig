const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ecs = @import("ecs");
const zlm = @import("zlm");
const zge = @import("zge");
const V = zge.vector.V;
const Vector = zge.vector.Vector;

const RigidBody = @import("../components.zig").RigidBody;
const CarAI = @import("../car-ai.zig").CarAI;
const Waypoint = @import("../car-ai.zig").Waypoint;
const animations = @import("../animations.zig");
const Direction = @import("../direction.zig").Direction;
const AnimationComponent = @import("../components.zig").AnimationComponent;

const carInternalFrictionConstant = 1 / 4;
const dragConstant = 1 / 40;
const fastAirDragConstant = 1 / 1600;
const carSafetyAwarenessDistanceFactor = 1;
const carSafetyAwarenessRadiusFactor = 0.4;
pub const carSafetyAwarenessRightEnabled = false;

pub const CarAISystem = struct {
    pub fn update(
        allocator: Allocator,
        reg: *ecs.Registry,
        physicsSystem: *zge.physics.PhysicsSystem,
    ) void {
        var view = reg.view(.{ CarAI, RigidBody }, .{});
        var it = view.entityIterator();

        while (it.next()) |entity| {
            updateCar(allocator, reg, physicsSystem, &view, entity);
        }
    }

    fn updateCar(
        allocator: Allocator,
        reg: *ecs.Registry,
        physicsSystem: *zge.physics.PhysicsSystem,
        view: *ecs.MultiView(2, 0),
        entity: ecs.Entity,
    ) void {
        const body = view.get(RigidBody, entity);
        const ai = view.get(CarAI, entity);

        updateCarNavigation(reg, body, ai);
        updateCarIntent(allocator, reg, physicsSystem, body, ai);
        updateCarPhysics(body, ai);
        updateCarAnimation(view, entity, body, ai);
    }

    /// Returns true if state was change because of local rules
    fn updateCarFollowingLocalRules(
        allocator: Allocator,
        physicsSystem: *zge.physics.PhysicsSystem,
        body: *RigidBody,
        ai: *CarAI,
    ) bool {
        if (ai.state != .givingPrecedence) return false;

        const intersections = physicsSystem.findIntersectionsRect(ai.state.givingPrecedence.rect);
        defer allocator.free(intersections);

        for (intersections) |intersection| {
            if (intersection.entry.key == body.key) continue;
            if (intersection.entry.s.isStatic or !intersection.entry.s.isSolid) continue;

            return true;
        }

        ai.state = .accelerating;

        return false;
    }

    pub const SafetyAwarenessCircle = struct {
        radius: f32,
        offset: Vector,
    };
    pub fn getSafetyAwarenessCircle(body: *RigidBody, ai: *CarAI) SafetyAwarenessCircle {
        const r = body.aabb.width() * carSafetyAwarenessDistanceFactor;
        const radius = body.aabb.width() * carSafetyAwarenessRadiusFactor;
        const v = body.d.cloneVel();
        const direction = if (V.length2(v) < 1) V.rotate(V.init(r, 0), ai.direction.r) else V.normalize(v) * V.scalar(r);
        const position = body.d.clonePos() + direction;

        return .{ .radius = radius, .offset = position };
    }

    pub fn getSafetyAwarenessCircleRight(body: *RigidBody, ai: *CarAI) SafetyAwarenessCircle {
        const r = body.aabb.width() * carSafetyAwarenessDistanceFactor;
        const radius = body.aabb.width() * carSafetyAwarenessRadiusFactor;
        const v = body.d.cloneVel();
        const direction = if (v.length2() < 1) V.init(1, 0).rotate(ai.direction.r).scale(r) else v.normalize().scale(r);
        const position = body.d.clonePos().add(direction.scale(1.5).add(direction.rotate(std.math.pi * 0.5)));

        return .{ .radius = radius, .offset = position };
    }

    /// Returns true if car is avoiding crash in front of the car
    fn updateCarSafetyAwareness(
        allocator: Allocator,
        reg: *ecs.Registry,
        physicsSystem: *zge.physics.PhysicsSystem,
        body: *RigidBody,
        ai: *CarAI,
    ) bool {
        const sac = getSafetyAwarenessCircle(body, ai);
        const intersections = physicsSystem.findIntersectionsCircle(sac.radius, sac.offset);
        defer allocator.free(intersections);

        for (intersections) |intersection| {
            if (intersection.entry.key == body.key) continue;
            if (intersection.entry.s.isStatic or !intersection.entry.s.isSolid) continue;

            ai.state = .{ .braking = ai.brakeForce };

            return true;
        }

        if (!carSafetyAwarenessRightEnabled) return false;

        const sacRight = getSafetyAwarenessCircleRight(body, ai);
        const intersectionsRight = physicsSystem.findIntersectionsCircle(sacRight.radius, sacRight.offset);
        defer allocator.free(intersectionsRight);

        for (intersectionsRight) |intersection| {
            if (intersection.entry.key == body.key) continue;
            if (intersection.entry.s.isStatic or !intersection.entry.s.isSolid) continue;

            const isCar = reg.tryGetConst(CarAI, intersection.entry.key) != null;
            if (!isCar) continue;

            ai.state = .{ .braking = ai.brakeForce };

            return true;
        }

        return false;
    }

    fn updateCarNavigation(
        reg: *ecs.Registry,
        body: *RigidBody,
        ai: *CarAI,
    ) void {
        const tolerance = 5;
        const currentTargetBody = reg.get(RigidBody, ai.waypoint);
        const dist = body.aabb.distance(currentTargetBody.aabb);

        if (dist < tolerance) {
            const waypoint = reg.get(Waypoint, ai.waypoint);

            // Remember to give precedence if necessary
            if (waypoint.givePrecedenceTo) |rect| {
                ai.state = .{ .givingPrecedence = .{ .waypoint = ai.waypoint, .rect = rect } };
            }

            // Randomly select new destination waypoint
            const rand = reg.singletons().get(std.Random.DefaultPrng).random();
            const link = waypoint.getRandomLink(rand);

            ai.waypoint = link;
        }

        const waypointBody = reg.get(RigidBody, ai.waypoint);
        const rel = waypointBody.aabb.center() - body.aabb.center();
        const r = std.math.atan2(V.y(rel), V.x(rel));

        ai.direction.set(r);
    }

    fn updateCarPhysics(body: *RigidBody, ai: *CarAI) void {
        updateCarFriction(body, &ai.direction);

        switch (ai.state) {
            .braking => |brakeForce| brake(body, brakeForce),
            .accelerating => accelerateToTarget(body, ai),
            .turning => accelerateToTarget(body, ai),
            .givingPrecedence => brake(body, ai.brakeForce),
        }
    }

    fn updateCarIntent(allocator: Allocator, reg: *ecs.Registry, physicsSystem: *zge.physics.PhysicsSystem, body: *RigidBody, ai: *CarAI) void {
        const isFollowingLocalRules = updateCarFollowingLocalRules(allocator, physicsSystem, body, ai);

        if (isFollowingLocalRules) return;

        const isAvoidingCrash = updateCarSafetyAwareness(allocator, reg, physicsSystem, body, ai);

        if (isAvoidingCrash) return;

        drivingNormally(reg, body, ai);
    }

    fn drivingNormally(reg: *ecs.Registry, body: *RigidBody, ai: *CarAI) void {
        const v = body.d.cloneVel();
        const velocityLength = V.length(v);
        const velocityDirection = std.math.atan2(V.y(v), V.x(v));

        const goingInCorrectDirection = ai.direction.approxEq(velocityDirection);
        const isSlowEnoughToTurn = velocityLength < ai.turnSpeedUpperBound;
        const isBelowSpeedLimit = velocityLength < ai.speedLimit;

        const currentTargetBody = reg.get(RigidBody, ai.waypoint);
        const dist = body.aabb.distance(currentTargetBody.aabb);
        const brakeDistanceTolerance = (body.aabb.width() / 3) * 2;
        const isCloseEnoughToBrake = dist < brakeDistanceTolerance;

        if (isCloseEnoughToBrake and !isSlowEnoughToTurn) {
            const bfx = (1 - dist / brakeDistanceTolerance);
            const bfy = -std.math.pow(f32, bfx - 1, 6) + 1;
            const brakeForce = bfy * ai.brakeForce * 0.8;
            ai.state = .{ .braking = brakeForce };
        } else if (!goingInCorrectDirection and isSlowEnoughToTurn and isBelowSpeedLimit) {
            ai.state = .accelerating;
        } else if (isBelowSpeedLimit) {
            ai.state = .accelerating;
        } else {
            if (!isBelowSpeedLimit) {
                ai.state = .{ .braking = ai.brakeForce };
            }

            const relToWaypoint = currentTargetBody.aabb.center() - body.aabb.center();
            const dx, const dy = relToWaypoint - v;

            if (@abs(dx) < @abs(dy)) {
                body.applyForce(V.init(dx, 0));
            } else {
                body.applyForce(V.init(0, dy));
            }
        }
    }

    fn brake(body: *RigidBody, brakeForce: f32) void {
        body.applyForce(V.normalize(-body.d.cloneVel()) * V.scalar(brakeForce));
    }

    fn accelerateToTarget(body: *RigidBody, ai: *CarAI) void {
        const engineForce = V.init(1, 0) * V.rotate(V.scalar(ai.accelerationForceMagnitude), ai.direction.r);

        body.applyForce(engineForce);
    }

    fn applyCarTurningFriction(body: *RigidBody, direction: *Direction) void {
        const a = body.d.cloneAccel();
        const v = body.d.cloneVel();

        const tireStickFriction = 0.5;
        const tireStickFrictionWhileSliding = 0.1;
        const slideThreshold = 300;
        const turnTransferVelocityFactor = 0.5;
        const turnTransferVelocityFactorWhileSliding = 0;

        // Calculate steepness of turn
        const perpendicular = V.normalize(V.rotate(a, std.math.pi / @as(f32, 2)));
        const vm = V.dot(v, perpendicular);
        const steepness = @max(@abs(vm) - slideThreshold, 0);

        const turningForceMagnitude: f32 = if (steepness > 0) tireStickFrictionWhileSliding else tireStickFriction;

        // Turning physics, makes car "lock in" when making a turn
        const f = V.init(
            if (direction.isVertical()) -V.x(v) * turningForceMagnitude else 0,
            if (direction.isHorizontal()) -V.y(v) * turningForceMagnitude else 0,
        );

        // Bring some of the velocity from the old direction into the new direction
        // so that we don't lose as much velocity when turning

        const turnKeepVelocityFactor: f32 = if (steepness > 0) turnTransferVelocityFactorWhileSliding else turnTransferVelocityFactor;
        const b = V.init(@abs(V.y(f)) * std.math.sign(V.x(a)), @abs(V.x(f)) * std.math.sign(V.y(a))) * V.scalar(turnKeepVelocityFactor);

        body.applyForce(f + b);
    }

    pub fn updateCarFriction(body: *RigidBody, direction: *Direction) void {
        applyCarTurningFriction(body, direction);

        const v = body.d.cloneVel();

        const internalFrictionForce = V.normalize(v) * V.scalar(carInternalFrictionConstant) * V.scalar(std.math.sign(V.length2(v)));
        const dragForce = v * V.scalar(dragConstant);
        const fastDragForce = v * v * V.scalar(fastAirDragConstant);

        const groundFrictionalForce = calculateFrictionalForce(body, 0.9, 0.8);

        const totalForce = internalFrictionForce + groundFrictionalForce + dragForce + fastDragForce;

        body.applyForce(totalForce);
    }

    fn calculateFrictionalForce(body: *RigidBody, static: f32, kinetic: f32) Vector {
        const v = body.d.cloneVel();
        const l = V.length(v);

        const u: f32 = if (l > 0) kinetic else static;

        const N = body.s.mass() * zge.physics.GRAVITY_EARTH;

        const magnitude = u * N;
        const direction = V.normalize(-v);

        if (V.length(direction) > l) {
            return -v;
        }

        return direction * V.scalar(magnitude);
    }

    fn updateCarAnimation(view: *ecs.MultiView(2, 0), entity: ecs.Entity, body: *RigidBody, ai: *CarAI) void {
        const v = body.d.cloneVel();
        const animation = view.get(AnimationComponent, entity);

        const animSpeed = animations.carAnimSpeed(v);

        animation.animationInstance.speed = animSpeed;

        if (ai.direction.isRight()) {
            animation.animationInstance.animation = ai.animations.right;
        } else if (ai.direction.isUp()) {
            animation.animationInstance.animation = ai.animations.up;
        } else if (ai.direction.isLeft()) {
            animation.animationInstance.animation = ai.animations.left;
        } else if (ai.direction.isDown()) {
            animation.animationInstance.animation = ai.animations.down;
        }
    }
};
