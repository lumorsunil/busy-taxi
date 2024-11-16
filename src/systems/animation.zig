const rl = @import("raylib");
const ecs = @import("ecs");

const TextureComponent = @import("zge").components.TextureComponent;
const AnimationComponent = @import("../components.zig").AnimationComponent;

pub const AnimationSystem = struct {
    pub fn update(_: *const AnimationSystem, reg: *ecs.Registry, t: f64) void {
        var view = reg.basicView(AnimationComponent);

        for (view.data()) |entity| {
            const animation = reg.get(AnimationComponent, entity);
            animation.animationInstance.update(t);
            reg.addOrReplace(entity, TextureComponent.init(animation.animationInstance.getCurrentTexture()));
        }
    }
};
