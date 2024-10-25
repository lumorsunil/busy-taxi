const std = @import("std");
const rl = @import("raylib");
const GameState = @import("state-config.zig").GameState;
const stateTextures = @import("state-config.zig").stateTextures;

const Camera = @import("camera.zig").Camera;

const DrawSystem = @import("systems/draw.zig").DrawSystem;

const roadSize: f32 = 32;
pub const Direction = enum { Up, Down, Left, Right };

pub fn drawRoad(state: *const GameState, p0: rl.Vector2, direction: Direction, length: usize, scale: f32, camera: Camera) void {
    const textures = stateTextures(state);

    var pA = rl.Vector2.init(p0.x, p0.y);
    var pB = rl.Vector2.init(p0.x, p0.y);
    var d: f32 = 1;
    var textureA: *const rl.Texture2D = undefined;
    var textureB: *const rl.Texture2D = undefined;

    if (direction == Direction.Left or direction == Direction.Right) {
        pB.y += 1;
        textureA = &textures.roadUp;
        textureB = &textures.roadDown;
    } else {
        pB.x += 1;
        textureA = &textures.roadLeft;
        textureB = &textures.roadRight;
    }

    if (direction == Direction.Left or direction == Direction.Up) {
        d = -1;
    }

    for (0..length) |_| {
        const pAs = rl.Vector2.init(pA.x * 32 * scale, pA.y * 32 * scale);
        const pBs = rl.Vector2.init(pB.x * 32 * scale, pB.y * 32 * scale);

        DrawSystem.drawTexture(textureA, pAs, 0, scale, camera);
        DrawSystem.drawTexture(textureB, pBs, 0, scale, camera);

        if (direction == Direction.Left or direction == Direction.Right) {
            pA.x += d;
            pB.x += d;
        } else if (direction == Direction.Up or direction == Direction.Down) {
            pA.y += d;
            pB.y += d;
        }
    }
}

pub fn drawIntersection(state: *const GameState, position: rl.Vector2, scale: f32, camera: Camera) void {
    const textures = stateTextures(state);
    const step = 32 * scale;

    const tl = rl.Vector2.init(position.x * step, position.y * step);
    const tr = rl.Vector2.init(tl.x + step, tl.y);
    const bl = rl.Vector2.init(position.x * step, (position.y + 1) * step);
    const br = rl.Vector2.init(bl.x + step, bl.y);

    DrawSystem.drawTexture(&textures.roadIntersectionTopLeft, tl, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadIntersectionTopRight, tr, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadIntersectionBottomLeft, bl, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadIntersectionBottomRight, br, 0, scale, camera);
}

pub fn drawTurnFromDownToRight(state: *const GameState, position: rl.Vector2, scale: f32, camera: Camera) void {
    const textures = stateTextures(state);
    const step = 32 * scale;

    const tl = rl.Vector2.init(position.x * step, position.y * step);
    const tr = rl.Vector2.init(tl.x + step, tl.y);
    const bl = rl.Vector2.init(position.x * step, (position.y + 1) * step);
    const br = rl.Vector2.init(bl.x + step, bl.y);

    DrawSystem.drawTexture(&textures.roadCornerTopLeft, tl, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadUp, tr, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadLeft, bl, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadIntersectionBottomRight, br, 0, scale, camera);
}

pub fn drawTurnFromUpToRight(state: *const GameState, position: rl.Vector2, scale: f32, camera: Camera) void {
    const textures = stateTextures(state);
    const step = 32 * scale;

    const tl = rl.Vector2.init(position.x * step, position.y * step);
    const tr = rl.Vector2.init(tl.x + step, tl.y);
    const bl = rl.Vector2.init(position.x * step, (position.y + 1) * step);
    const br = rl.Vector2.init(bl.x + step, bl.y);

    DrawSystem.drawTexture(&textures.roadLeft, tl, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadIntersectionTopRight, tr, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadCornerBottomLeft, bl, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadDown, br, 0, scale, camera);
}

pub fn drawTurnFromLeftToUp(state: *const GameState, position: rl.Vector2, scale: f32, camera: Camera) void {
    const textures = stateTextures(state);
    const step = 32 * scale;

    const tl = rl.Vector2.init(position.x * step, position.y * step);
    const tr = rl.Vector2.init(tl.x + step, tl.y);
    const bl = rl.Vector2.init(position.x * step, (position.y + 1) * step);
    const br = rl.Vector2.init(bl.x + step, bl.y);

    DrawSystem.drawTexture(&textures.roadIntersectionTopLeft, tl, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadRight, tr, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadDown, bl, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadCornerBottomRight, br, 0, scale, camera);
}

pub fn drawTurnFromLeftToDown(state: *const GameState, position: rl.Vector2, scale: f32, camera: Camera) void {
    const textures = stateTextures(state);
    const step = 32 * scale;

    const tl = rl.Vector2.init(position.x * step, position.y * step);
    const tr = rl.Vector2.init(tl.x + step, tl.y);
    const bl = rl.Vector2.init(position.x * step, (position.y + 1) * step);
    const br = rl.Vector2.init(bl.x + step, bl.y);

    DrawSystem.drawTexture(&textures.roadUp, tl, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadCornerTopRight, tr, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadIntersectionBottomLeft, bl, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadRight, br, 0, scale, camera);
}

pub fn drawTIntersectionHorizontalUp(state: *const GameState, position: rl.Vector2, scale: f32, camera: Camera) void {
    const textures = stateTextures(state);
    const step = 32 * scale;

    const tl = rl.Vector2.init(position.x * step, position.y * step);
    const tr = rl.Vector2.init(tl.x + step, tl.y);
    const bl = rl.Vector2.init(position.x * step, (position.y + 1) * step);
    const br = rl.Vector2.init(bl.x + step, bl.y);

    DrawSystem.drawTexture(&textures.roadIntersectionTopLeft, tl, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadIntersectionTopRight, tr, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadDown, bl, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadDown, br, 0, scale, camera);
}

pub fn drawTIntersectionHorizontalDown(state: *const GameState, position: rl.Vector2, scale: f32, camera: Camera) void {
    const textures = stateTextures(state);
    const step = 32 * scale;

    const tl = rl.Vector2.init(position.x * step, position.y * step);
    const tr = rl.Vector2.init(tl.x + step, tl.y);
    const bl = rl.Vector2.init(position.x * step, (position.y + 1) * step);
    const br = rl.Vector2.init(bl.x + step, bl.y);

    DrawSystem.drawTexture(&textures.roadUp, tl, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadUp, tr, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadIntersectionBottomLeft, bl, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadIntersectionBottomRight, br, 0, scale, camera);
}

pub fn drawTIntersectionVerticalLeft(state: *const GameState, position: rl.Vector2, scale: f32, camera: Camera) void {
    const textures = stateTextures(state);
    const step = 32 * scale;

    const tl = rl.Vector2.init(position.x * step, position.y * step);
    const tr = rl.Vector2.init(tl.x + step, tl.y);
    const bl = rl.Vector2.init(position.x * step, (position.y + 1) * step);
    const br = rl.Vector2.init(bl.x + step, bl.y);

    DrawSystem.drawTexture(&textures.roadIntersectionTopLeft, tl, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadRight, tr, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadIntersectionBottomLeft, bl, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadRight, br, 0, scale, camera);
}

pub fn drawTIntersectionVerticalRight(state: *const GameState, position: rl.Vector2, scale: f32, camera: Camera) void {
    const textures = stateTextures(state);
    const step = 32 * scale;

    const tl = rl.Vector2.init(position.x * step, position.y * step);
    const tr = rl.Vector2.init(tl.x + step, tl.y);
    const bl = rl.Vector2.init(position.x * step, (position.y + 1) * step);
    const br = rl.Vector2.init(bl.x + step, bl.y);

    DrawSystem.drawTexture(&textures.roadLeft, tl, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadIntersectionTopRight, tr, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadLeft, bl, 0, scale, camera);
    DrawSystem.drawTexture(&textures.roadIntersectionBottomRight, br, 0, scale, camera);
}
