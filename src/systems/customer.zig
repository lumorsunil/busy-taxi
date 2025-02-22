const std = @import("std");
const ecs = @import("ecs");
const zlm = @import("zlm");

const zge = @import("zge");
const RigidBody = zge.physics.RigidBody;
const Invisible = zge.components.Invisible;
const V = zge.vector.V;
const Vector = zge.vector.Vector;

const Label = @import("../components.zig").Label;
const AnimationComponent = @import("../components.zig").AnimationComponent;
const CustomerComponent = @import("../components.zig").CustomerComponent;
const LocationComponent = @import("../components.zig").LocationComponent;

const cfg = @import("../config.zig");

const playerSpeedWhenPickingUp = 32;

pub const CustomerSystem = struct {
    pub fn update(reg: *ecs.Registry, player: ecs.Entity) void {
        const playerBody = reg.getConst(RigidBody, player);
        const view = reg.basicView(CustomerComponent);

        for (view.data()) |entity| {
            const customerComponent = reg.get(CustomerComponent, entity);

            switch (customerComponent.state) {
                .transportingToDropOff => |dropOff| {
                    handleTransportingToDropOff(reg, entity, customerComponent, dropOff, playerBody);
                },
                .walkingToDropOff => |dropOff| {
                    handleWalkingToDropOff(reg, entity, dropOff);
                },
                .waitingForTransport => {
                    handleWaitingForTransport(reg, entity, customerComponent, playerBody);
                },
            }
        }
    }

    fn handleWaitingForTransport(reg: *ecs.Registry, customer: ecs.Entity, customerComponent: *CustomerComponent, playerBody: RigidBody) void {
        const customerBody = reg.get(RigidBody, customer);

        const customerC = customerBody.aabb.center();
        const playerC = playerBody.aabb.center();

        const distanceToPlayer = V.distance(playerC, customerC);
        const playerSpeed = V.length(playerBody.d.cloneVel());

        if (distanceToPlayer > 64 or playerSpeed > playerSpeedWhenPickingUp) return;

        if (distanceToPlayer < 16) {
            customerEntersCar(reg, customer, customerComponent, playerC);
            return;
        }

        var animation = reg.get(AnimationComponent, customer);
        animation.animationInstance.unPause();

        const d = playerC - customerC;
        const r = std.math.atan2(V.y(d), V.x(d));
        const walkSpeed = 10;
        customerBody.d.setVel(V.init(
            std.math.cos(r) * walkSpeed,
            std.math.sin(r) * walkSpeed,
        ));
    }

    fn customerEntersCar(
        reg: *ecs.Registry,
        customer: ecs.Entity,
        customerComponent: *CustomerComponent,
        playerPosition: Vector,
    ) void {
        reg.add(customer, Invisible{});

        const view = reg.basicView(LocationComponent);

        var locationCandidates: [100]struct { location: *const LocationComponent } = undefined;
        var lci: usize = 0;
        for (view.raw()) |*location| {
            if (V.distance(playerPosition, location.entrancePosition) < 1024) continue;

            locationCandidates[lci] = .{ .location = location };
            lci += 1;
        }

        if (lci == 0) unreachable;

        const randomCandidateIndex = reg.singletons().get(std.Random.DefaultPrng).random().uintLessThan(usize, lci);
        const destination = locationCandidates[randomCandidateIndex].location.entrancePosition;

        customerComponent.state = .{ .transportingToDropOff = .{ .destination = destination } };
    }

    fn handleTransportingToDropOff(reg: *ecs.Registry, customer: ecs.Entity, customerComponent: *CustomerComponent, dropOff: CustomerComponent.DropOff, playerBody: RigidBody) void {
        var customerBody = reg.get(RigidBody, customer);

        const playerC = playerBody.aabb.center();

        customerBody.d.setPos(playerC - V.init(8, 16));

        const customerC = customerBody.aabb.center();

        if (V.distance(customerC, dropOff.destination) < 32 and V.length(playerBody.d.cloneVel()) < playerSpeedWhenPickingUp) {
            // Drop off
            reg.remove(Invisible, customer);

            var animation = reg.get(AnimationComponent, customer);
            animation.animationInstance.unPause();

            customerComponent.state = .{ .walkingToDropOff = dropOff };
            return;
        }
    }

    fn handleWalkingToDropOff(reg: *ecs.Registry, customer: ecs.Entity, dropOff: CustomerComponent.DropOff) void {
        var customerBody = reg.get(RigidBody, customer);

        const customerC = customerBody.aabb.center();
        const target = dropOff.destination - V.init(0, 32);

        if (V.distance(customerC, target) < 2) {
            handleWalkedToDropOff(reg, customer);
            return;
        }

        const d = target - customerC;
        const r = std.math.atan2(V.y(d), V.x(d));
        const walkSpeed = 10;
        customerBody.d.setVel(V.init(
            std.math.cos(r) * walkSpeed,
            std.math.sin(r) * walkSpeed,
        ));
    }

    fn handleWalkedToDropOff(reg: *ecs.Registry, customer: ecs.Entity) void {
        reg.destroy(customer);
    }
};
