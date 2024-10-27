const std = @import("std");
const rl = @import("raylib");

const GameState = @import("../state-config.zig").GameState;
const Transform = @import("../components.zig").Transform;
const Physics = @import("../components.zig").Physics;
const Label = @import("../components.zig").Label;
const AnimationComponent = @import("../components.zig").AnimationComponent;
const CustomerComponent = @import("../components.zig").CustomerComponent;
const LocationComponent = @import("../components.zig").LocationComponent;
const Invisible = @import("../components.zig").Invisible;

const cfg = @import("../config.zig");

const playerSpeedWhenPickingUp = 32;

pub const CustomerSystem = struct {
    pub fn update(s: *GameState, player: usize) void {
        const playerTransform = s.getComponent(Transform, player) catch unreachable;
        const playerPhysics = s.getComponent(Physics, player) catch unreachable;

        for (0..s.entities.len) |entity| {
            const customerComponent = s.getComponent(CustomerComponent, entity) catch continue;

            switch (customerComponent.state) {
                .transportingToDropOff => |dropOff| {
                    handleTransportingToDropOff(s, entity, customerComponent, dropOff, playerPhysics, playerTransform);
                },
                .walkingToDropOff => |dropOff| {
                    handleWalkingToDropOff(s, entity, dropOff);
                },
                .waitingForTransport => {
                    handleWaitingForTransport(s, entity, customerComponent, playerTransform, playerPhysics);
                },
            }
        }
    }

    fn handleWaitingForTransport(s: *GameState, customer: usize, customerComponent: *CustomerComponent, playerTransform: *Transform, playerPhysics: *Physics) void {
        const customerTransform = s.getComponent(Transform, customer) catch return;

        const customerC = rl.Vector2.init(customerTransform.p.x + 8, customerTransform.p.y + 16);
        const playerC = rl.Vector2.init(playerTransform.p.x + 32, playerTransform.p.y + 32);

        const distanceToPlayer = playerC.distance(customerC);
        const playerSpeed = playerPhysics.v.length();

        if (distanceToPlayer > 64 or playerSpeed > playerSpeedWhenPickingUp) return;

        if (distanceToPlayer < 16) {
            customerEntersCar(s, customer, customerComponent, playerC);
            return;
        }

        var animation = s.getComponent(AnimationComponent, customer) catch unreachable;
        animation.animationInstance.unPause();

        var customerPhysics = s.getComponent(Physics, customer) catch return;

        const dx = playerC.x - customerC.x;
        const dy = playerC.y - customerC.y;
        const r = std.math.atan2(dy, dx);
        const walkSpeed = 10;
        customerPhysics.v.x = std.math.cos(r) * walkSpeed;
        customerPhysics.v.y = std.math.sin(r) * walkSpeed;
    }

    fn customerEntersCar(s: *GameState, customer: usize, customerComponent: *CustomerComponent, playerPosition: rl.Vector2) void {
        s.setComponent(Invisible, customer, .{});

        var locationCandidates: [cfg.MAX_ENTITIES]struct { location: *const LocationComponent } = undefined;
        var lci: usize = 0;
        for (0..s.entities.len) |candidate| {
            const lcLocation = s.getComponent(LocationComponent, candidate) catch continue;

            if (playerPosition.distance(lcLocation.entrancePosition) < 1024) continue;

            locationCandidates[lci] = .{ .location = lcLocation };
            lci += 1;
        }

        if (lci == 0) unreachable;

        const randomCandidateIndex = s.rand.random().uintLessThan(usize, lci);
        const destination = locationCandidates[randomCandidateIndex].location.entrancePosition;

        std.log.info("CUSTOMERSTATE: transportingToDropOff: {}", .{destination});
        customerComponent.state = .{ .transportingToDropOff = .{ .destination = destination } };
    }

    fn handleTransportingToDropOff(s: *GameState, customer: usize, customerComponent: *CustomerComponent, dropOff: CustomerComponent.DropOff, playerPhysics: *Physics, playerTransform: *Transform) void {
        var transform = s.getComponent(Transform, customer) catch unreachable;

        const playerC = rl.Vector2.init(playerTransform.p.x + 32, playerTransform.p.y + 32);

        transform.p.x = playerC.x - 8;
        transform.p.y = playerC.y - 16;

        const customerC = rl.Vector2.init(transform.p.x + 8, transform.p.y + 16);

        if (customerC.distance(dropOff.destination) < 32 and playerPhysics.v.length() < playerSpeedWhenPickingUp) {
            // Drop off
            s.removeComponent(Invisible, customer);
            transform.p.x = playerC.x - 8;
            transform.p.y = playerC.y - 16;

            var animation = s.getComponent(AnimationComponent, customer) catch unreachable;
            animation.animationInstance.unPause();

            customerComponent.state = .{ .walkingToDropOff = dropOff };
            return;
        }
    }

    fn handleWalkingToDropOff(s: *GameState, customer: usize, dropOff: CustomerComponent.DropOff) void {
        var physics = s.getComponent(Physics, customer) catch unreachable;
        const transform = s.getComponent(Transform, customer) catch unreachable;

        const customerC = rl.Vector2.init(transform.p.x + 8, transform.p.y + 16);
        const target = rl.Vector2.init(
            dropOff.destination.x,
            dropOff.destination.y - 32,
        );

        if (customerC.distance(target) < 2) {
            handleWalkedToDropOff(s, customer);
            return;
        }

        const dx = target.x - customerC.x;
        const dy = target.y - customerC.y;
        const r = std.math.atan2(dy, dx);
        const walkSpeed = 10;
        physics.v.x = std.math.cos(r) * walkSpeed;
        physics.v.y = std.math.sin(r) * walkSpeed;
    }

    fn handleWalkedToDropOff(s: *GameState, customer: usize) void {
        s.destroyEntity(customer) catch unreachable;
    }
};
