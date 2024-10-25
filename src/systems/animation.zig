const std = @import("std");
const rl = @import("raylib");

const GameState = @import("../state-config.zig").GameState;
const AnimationComponent = @import("../components.zig").AnimationComponent;

pub const AnimationSystem = struct {
    pub fn update(_: *const AnimationSystem, s: *GameState, t: f64) void {
        for (0..s.entities.len) |entity| {
            const animation = s.getComponent(AnimationComponent, entity) catch continue;
            animation.animationInstance.update(t);
            s.setComponent(*const rl.Texture2D, entity, animation.animationInstance.getCurrentTexture());
        }
    }
};
