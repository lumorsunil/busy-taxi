const std = @import("std");
const rl = @import("raylib");
const ecs = @import("ecs");
const zlm = @import("zlm");

const Textures = @import("../textures.zig").Textures;

const TextureComponent = @import("zge").components.TextureComponent;
const RigidBody = @import("zge").physics.RigidBody;
const RandomWalk = @import("../components.zig").RandomWalk;
const AnimationComponent = @import("../components.zig").AnimationComponent;

const walkSpeed = 10;

pub const RandomWalkSystem = struct {
    pub fn update(reg: *ecs.Registry, textures: *const Textures(rl.Texture2D), t: f64) void {
        var view = reg.view(.{ RandomWalk, RigidBody, AnimationComponent }, .{});
        var it = view.entityIterator();

        while (it.next()) |entity| {
            const randomWalk = reg.get(RandomWalk, entity);
            const body = reg.get(RigidBody, entity);
            const animation = reg.get(AnimationComponent, entity);

            const newState = randomWalk.update(t);

            if (newState) |state| {
                switch (state) {
                    .idle => {
                        reg.addOrReplace(entity, TextureComponent.init(&textures.pedestrianBlueIdle));
                        animation.animationInstance.pause();
                        body.d.setVel(zlm.Vec2.zero);
                    },
                    .walking => {
                        body.d.setVel(zlm.vec2(
                            std.math.cos(randomWalk.walkDirection) * walkSpeed,
                            std.math.sin(randomWalk.walkDirection) * walkSpeed,
                        ));
                        animation.animationInstance.unPause();
                    },
                }
            }
        }
    }
};
