const std = @import("std");
const Allocator = std.mem.Allocator;
const zlm = @import("zlm");
const zge = @import("zge");
const V = zge.vector.V;
const Vector = zge.vector.Vector;

const rl = @import("raylib");

const Textures = @import("textures.zig").Textures;
const Animation = @import("animation.zig").Animation;
const AnimationFrame = @import("animation.zig").AnimationFrame;

pub fn carAnimSpeed(v: Vector) f32 {
    const x, const y = @abs(v);

    return 1000 / (x * x + x * 100 + y * y + y * 100);
}

pub fn carBlackLeftAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 2) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.carBlackLeft1, .duration = 1 };
    frames[1] = AnimationFrame{ .texture = &textures.carBlackLeft2, .duration = 1 };

    return Animation.init(frames);
}

pub fn carBlackRightAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 2) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.carBlackRight1, .duration = 1 };
    frames[1] = AnimationFrame{ .texture = &textures.carBlackRight2, .duration = 1 };

    return Animation.init(frames);
}

pub fn carBlackUpAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 2) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.carBlackUp1, .duration = 1 };
    frames[1] = AnimationFrame{ .texture = &textures.carBlackUp2, .duration = 1 };

    return Animation.init(frames);
}

pub fn carBlackDownAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 2) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.carBlackDown1, .duration = 1 };
    frames[1] = AnimationFrame{ .texture = &textures.carBlackDown2, .duration = 1 };

    return Animation.init(frames);
}

pub fn carRedLeftAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 2) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.carRedLeft1, .duration = 1 };
    frames[1] = AnimationFrame{ .texture = &textures.carRedLeft2, .duration = 1 };

    return Animation.init(frames);
}

pub fn carRedRightAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 2) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.carRedRight1, .duration = 1 };
    frames[1] = AnimationFrame{ .texture = &textures.carRedRight2, .duration = 1 };

    return Animation.init(frames);
}

pub fn carRedUpAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 2) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.carRedUp1, .duration = 1 };
    frames[1] = AnimationFrame{ .texture = &textures.carRedUp2, .duration = 1 };

    return Animation.init(frames);
}

pub fn carRedDownAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 2) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.carRedDown1, .duration = 1 };
    frames[1] = AnimationFrame{ .texture = &textures.carRedDown2, .duration = 1 };

    return Animation.init(frames);
}

pub fn carGreenLeftAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 2) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.carGreenLeft1, .duration = 1 };
    frames[1] = AnimationFrame{ .texture = &textures.carGreenLeft2, .duration = 1 };

    return Animation.init(frames);
}

pub fn carGreenRightAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 2) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.carGreenRight1, .duration = 1 };
    frames[1] = AnimationFrame{ .texture = &textures.carGreenRight2, .duration = 1 };

    return Animation.init(frames);
}

pub fn carGreenUpAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 2) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.carGreenUp1, .duration = 1 };
    frames[1] = AnimationFrame{ .texture = &textures.carGreenUp2, .duration = 1 };

    return Animation.init(frames);
}

pub fn carGreenDownAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 2) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.carGreenDown1, .duration = 1 };
    frames[1] = AnimationFrame{ .texture = &textures.carGreenDown2, .duration = 1 };

    return Animation.init(frames);
}

pub fn carWhiteLeftAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 2) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.carWhiteLeft1, .duration = 1 };
    frames[1] = AnimationFrame{ .texture = &textures.carWhiteLeft2, .duration = 1 };

    return Animation.init(frames);
}

pub fn carWhiteRightAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 2) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.carWhiteRight1, .duration = 1 };
    frames[1] = AnimationFrame{ .texture = &textures.carWhiteRight2, .duration = 1 };

    return Animation.init(frames);
}

pub fn carWhiteUpAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 2) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.carWhiteUp1, .duration = 1 };
    frames[1] = AnimationFrame{ .texture = &textures.carWhiteUp2, .duration = 1 };

    return Animation.init(frames);
}

pub fn carWhiteDownAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 2) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.carWhiteDown1, .duration = 1 };
    frames[1] = AnimationFrame{ .texture = &textures.carWhiteDown2, .duration = 1 };

    return Animation.init(frames);
}

pub fn carPurpleLeftAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 2) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.carPurpleLeft1, .duration = 1 };
    frames[1] = AnimationFrame{ .texture = &textures.carPurpleLeft2, .duration = 1 };

    return Animation.init(frames);
}

pub fn carPurpleRightAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 2) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.carPurpleRight1, .duration = 1 };
    frames[1] = AnimationFrame{ .texture = &textures.carPurpleRight2, .duration = 1 };

    return Animation.init(frames);
}

pub fn carPurpleUpAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 2) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.carPurpleUp1, .duration = 1 };
    frames[1] = AnimationFrame{ .texture = &textures.carPurpleUp2, .duration = 1 };

    return Animation.init(frames);
}

pub fn carPurpleDownAnimation(allocator: Allocator, textures: *const Textures(rl.Texture2D)) Animation {
    const frames = allocator.alloc(AnimationFrame, 2) catch unreachable;

    frames[0] = AnimationFrame{ .texture = &textures.carPurpleDown1, .duration = 1 };
    frames[1] = AnimationFrame{ .texture = &textures.carPurpleDown2, .duration = 1 };

    return Animation.init(frames);
}

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
