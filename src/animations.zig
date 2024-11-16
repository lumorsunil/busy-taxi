const std = @import("std");
const Allocator = std.mem.Allocator;

const rl = @import("raylib");

const Textures = @import("textures.zig").Textures;
const Animation = @import("animation.zig").Animation;
const AnimationFrame = @import("animation.zig").AnimationFrame;

pub fn pedestrianBlueWalkAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 8) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.pedestrianBlueIdle, .duration = 0.1 };
    frames[1] = AnimationFrame{ .texture = &textures.pedestrianBlueWalk1, .duration = 0.1 };
    frames[2] = AnimationFrame{ .texture = &textures.pedestrianBlueWalk2, .duration = 0.1 };
    frames[3] = AnimationFrame{ .texture = &textures.pedestrianBlueWalk1, .duration = 0.1 };
    frames[4] = AnimationFrame{ .texture = &textures.pedestrianBlueIdle, .duration = 0.1 };
    frames[5] = AnimationFrame{ .texture = &textures.pedestrianBlueWalk3, .duration = 0.1 };
    frames[6] = AnimationFrame{ .texture = &textures.pedestrianBlueWalk4, .duration = 0.1 };
    frames[7] = AnimationFrame{ .texture = &textures.pedestrianBlueWalk3, .duration = 0.1 };

    return Animation.init(frames);
}

pub fn pedestrianRedWalkAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 8) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.pedestrianRedIdle, .duration = 0.1 };
    frames[1] = AnimationFrame{ .texture = &textures.pedestrianRedWalk1, .duration = 0.1 };
    frames[2] = AnimationFrame{ .texture = &textures.pedestrianRedWalk2, .duration = 0.1 };
    frames[3] = AnimationFrame{ .texture = &textures.pedestrianRedWalk1, .duration = 0.1 };
    frames[4] = AnimationFrame{ .texture = &textures.pedestrianRedIdle, .duration = 0.1 };
    frames[5] = AnimationFrame{ .texture = &textures.pedestrianRedWalk3, .duration = 0.1 };
    frames[6] = AnimationFrame{ .texture = &textures.pedestrianRedWalk4, .duration = 0.1 };
    frames[7] = AnimationFrame{ .texture = &textures.pedestrianRedWalk3, .duration = 0.1 };

    return Animation.init(frames);
}
