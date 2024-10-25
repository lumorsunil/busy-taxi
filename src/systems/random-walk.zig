const std = @import("std");
const rl = @import("raylib");
const GameState = @import("../state-config.zig").GameState;
const RandomWalk = @import("../components.zig").RandomWalk;
const Physics = @import("../components.zig").Physics;
const AnimationComponent = @import("../components.zig").AnimationComponent;

const walkSpeed = 10;

pub const RandomWalkSystem = struct {
    pub fn update(s: *GameState, t: f64) void {
        for (0..s.entities.len) |entity| {
            const randomWalk = s.getComponent(RandomWalk, entity) catch continue;
            const physics = s.getComponent(Physics, entity) catch continue;
            const animation = s.getComponent(AnimationComponent, entity) catch continue;

            const newState = randomWalk.update(t);

            if (newState) |state| {
                switch (state) {
                    .idle => {
                        s.setComponent(*const rl.Texture2D, entity, &s.textures.pedestrianBlueIdle);
                        animation.animationInstance.pause();
                        physics.v.x = 0;
                        physics.v.y = 0;
                    },
                    .walking => {
                        physics.v.x = std.math.cos(randomWalk.walkDirection) * walkSpeed;
                        physics.v.y = std.math.sin(randomWalk.walkDirection) * walkSpeed;
                        animation.animationInstance.unPause();
                    },
                }
            }
        }
    }
};
