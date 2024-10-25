const std = @import("std");
const rl = @import("raylib");

const GameState = @import("../state-config.zig").GameState;
const Transform = @import("../components.zig").Transform;
const Physics = @import("../components.zig").Physics;
const Label = @import("../components.zig").Label;
const AnimationComponent = @import("../components.zig").AnimationComponent;

pub const CustomerSystem = struct {
    pub fn update(s: *GameState, player: usize) void {
        const playerTransform = s.getComponent(Transform, player) catch unreachable;
        const playerPhysics = s.getComponent(Physics, player) catch unreachable;

        for (0..s.entities.len) |entity| {
            const label = s.getComponent(Label, entity) catch continue;

            if (!std.mem.eql(u8, label.label, "Customer")) continue;

            const customerTransform = s.getComponent(Transform, entity) catch continue;

            const customerC = rl.Vector2.init(customerTransform.p.x + 8, customerTransform.p.y + 16);
            const playerC = rl.Vector2.init(playerTransform.p.x + 32, playerTransform.p.y + 32);

            const distanceToPlayer = playerC.distance(customerC);
            const playerSpeed = playerPhysics.v.length();

            if (distanceToPlayer > 64 or playerSpeed > 100) return;

            if (distanceToPlayer < 16) {
                // Customer enters car
                s.removeComponent(*const rl.Texture2D, entity);
                s.removeComponent(AnimationComponent, entity);
                return;
            }

            var customerPhysics = s.getComponent(Physics, entity) catch continue;

            //const r = std.math.degreesToRadians(customerC.angle(playerC));
            const dx = playerC.x - customerC.x;
            const dy = playerC.y - customerC.y;
            const r = std.math.atan2(dy, dx);
            const walkSpeed = 10;
            customerPhysics.v.x = std.math.cos(r) * walkSpeed;
            customerPhysics.v.y = std.math.sin(r) * walkSpeed;
        }
    }
};
