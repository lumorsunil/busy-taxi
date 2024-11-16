const std = @import("std");
const zlm = @import("zlm");
const zge = @import("zge");
const rl = @import("raylib");

const animation = @import("animation.zig");

pub const RigidBody = zge.physics.RigidBody;

pub const Label = struct {
    label: []const u8,
};

pub const AnimationComponent = struct {
    animationInstance: animation.AnimationInstance,
};

pub const RandomWalk = struct {
    state: State,
    walkDirection: f32,
    nextStateAt: f64,

    var rand = std.Random.DefaultPrng.init(0);

    const baselineDuration = 6;
    const baselineVariation = 2;

    pub const State = enum {
        idle,
        walking,
    };

    pub fn init() RandomWalk {
        return RandomWalk{
            .state = State.idle,
            .walkDirection = 0,
            .nextStateAt = 0,
        };
    }

    pub fn update(self: *RandomWalk, t: f64) ?State {
        if (self.nextStateAt <= t) {
            self.nextStateAt = self.getNextStateAt();
            self.walkDirection = rand.random().float(f32) * std.math.pi * 2;
            self.state = self.getNextState();

            return self.state;
        }

        return null;
    }

    fn getNextState(_: RandomWalk) State {
        const r = rand.random().float(f32);

        if (r < 0.2) {
            return State.idle;
        } else {
            return State.walking;
        }
    }

    fn getNextStateAt(self: RandomWalk) f64 {
        return self.nextStateAt + baselineDuration + rand.random().float(f64) * baselineVariation;
    }
};

pub const CustomerComponent = struct {
    state: State = .waitingForTransport,

    pub const DropOff = struct {
        destination: zlm.Vec2,
    };

    pub const State = union(enum) {
        waitingForTransport,
        walkingToDropOff: DropOff,
        transportingToDropOff: DropOff,
    };
};

pub const LocationComponent = struct {
    entrancePosition: zlm.Vec2,
};

pub const DropOffLocation = struct {};

pub const Invisible = struct {};
