const std = @import("std");
const zlm = @import("zlm");
const zge = @import("zge");
const rl = @import("raylib");
const ecs = @import("ecs");
const Vector = zge.vector.Vector;

const animation = @import("animation.zig");

pub const RigidBody = zge.physics.RigidBody;

pub const Label = struct {
    label: []const u8,
};

pub const AnimationComponent = struct {
    animationInstance: animation.AnimationInstance,
};

pub const PedestrianAI = struct {
    state: State,
    nextStateAt: f64,

    var rand = std.Random.DefaultPrng.init(0);

    const baselineDuration = 6;
    const baselineVariation = 2;

    pub const State = union(enum) {
        idle,
        walking: Moving,
        avoiding: Avoiding,

        pub const Moving = struct {
            direction: f32,
            speed: f32,
        };

        pub const Avoiding = struct {
            velocity: Vector,
        };
    };

    pub const WALK_SPEED = 10;
    pub const RUN_SPEED = 50;
    pub const JUMP_SPEED = 200;
    pub const JUMP_DURATION = 0.2;

    pub fn init() PedestrianAI {
        return PedestrianAI{
            .state = .idle,
            .nextStateAt = 0,
        };
    }

    pub fn update(self: *PedestrianAI, t: f64) ?State {
        if (self.nextStateAt <= t) {
            self.nextStateAt = self.getNextStateAt();
            self.state = self.getNextState();

            return self.state;
        }

        return null;
    }

    fn getNextState(_: PedestrianAI) State {
        const r = rand.random().float(f32);

        if (r < 0.2) {
            return .idle;
        } else {
            return .{ .walking = .{
                .direction = rand.random().float(f32) * std.math.pi * 2,
                .speed = WALK_SPEED,
            } };
        }
    }

    fn getNextStateAt(self: PedestrianAI) f64 {
        return self.nextStateAt + baselineDuration + rand.random().float(f64) * baselineVariation;
    }
};

pub const CustomerComponent = struct {
    state: State = .waitingForTransport,

    pub const DropOff = struct {
        destination: Vector,
    };

    pub const State = union(enum) {
        waitingForTransport,
        walkingToDropOff: DropOff,
        transportingToDropOff: DropOff,
    };
};

pub const LocationComponent = struct {
    entrancePosition: Vector,
};

pub const DropOffLocation = struct {};
