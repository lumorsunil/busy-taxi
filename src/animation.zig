const std = @import("std");
const Allocator = std.mem.Allocator;

const rl = @import("raylib");

pub const AnimationFrame = struct {
    duration: f32,
    texture: *const rl.Texture2D,
};

pub const Animation = struct {
    frames: []AnimationFrame,
    speed: f32,

    pub fn init(frames: []AnimationFrame) Animation {
        return Animation{
            .frames = frames,
            .speed = 1,
        };
    }

    pub fn deinit(self: *Animation, allocator: Allocator) void {
        allocator.free(self.frames);
    }
};

pub const AnimationInstance = struct {
    animation: *const Animation,
    currentFrame: usize,
    nextFrameAt: f64,
    speed: f32,
    isPaused: bool,

    pub fn init(animation: *const Animation) AnimationInstance {
        var instance = AnimationInstance{
            .animation = animation,
            .currentFrame = 0,
            .nextFrameAt = undefined,
            .speed = 1,
            .isPaused = false,
        };

        instance.nextFrameAt = instance.getNextFrameAt();

        return instance;
    }

    pub fn getNextFrameAt(self: AnimationInstance) f64 {
        return self.nextFrameAt + self.animation.frames[self.currentFrame].duration * self.animation.speed * self.speed;
    }

    pub fn update(self: *AnimationInstance, t: f64) void {
        if (!self.isPaused and t >= self.nextFrameAt) {
            self.currentFrame = @mod(self.currentFrame + 1, self.animation.frames.len);
            self.nextFrameAt = self.getNextFrameAt();
        }
    }

    pub fn getCurrentTexture(self: AnimationInstance) *const rl.Texture2D {
        return self.animation.frames[self.currentFrame].texture;
    }

    pub fn pause(self: *AnimationInstance) void {
        self.isPaused = true;
    }

    pub fn unPause(self: *AnimationInstance) void {
        self.isPaused = false;
    }

    pub fn reset(self: *AnimationInstance) void {
        self.isPaused = false;
        self.speed = 1;
        self.currentFrame = 0;
        self.nextFrameAt = self.getNextFrameAt();
    }
};
