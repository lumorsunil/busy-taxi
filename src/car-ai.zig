const std = @import("std");
const ecs = @import("ecs");
const zge = @import("zge");
const AABB = zge.physics.shape.AABB;

const Animation = @import("animation.zig").Animation;
const Direction = @import("direction.zig").Direction;

pub const CarAI = struct {
    direction: Direction,
    waypoint: ecs.Entity,
    speedLimit: f32,
    turnSpeedUpperBound: f32,
    accelerationForceMagnitude: f32,
    brakeForce: f32,
    animations: Animations,
    state: State,

    pub const Animations = struct {
        right: *Animation,
        up: *Animation,
        left: *Animation,
        down: *Animation,
    };

    pub const State = union(enum) {
        braking: f32,
        accelerating,
        turning,
        givingPrecedence: GivingPrecedence,

        pub const GivingPrecedence = struct {
            waypoint: ecs.Entity,
            rect: AABB,
        };
    };

    pub fn init(direction: f32, waypoint: ecs.Entity, animations: Animations) CarAI {
        return CarAI{
            .direction = Direction{ .r = direction },
            .waypoint = waypoint,
            .speedLimit = 100,
            .turnSpeedUpperBound = 25,
            .accelerationForceMagnitude = 20,
            .brakeForce = 30,
            .animations = animations,
            .state = .accelerating,
        };
    }
};

pub const Waypoint = struct {
    links: [MAX_LINKS]?ecs.Entity,
    givePrecedenceTo: ?AABB,

    const MAX_LINKS = 10;

    pub fn init() Waypoint {
        return Waypoint{
            .links = .{null} ** MAX_LINKS,
            .givePrecedenceTo = null,
        };
    }

    pub fn connect(from: *Waypoint, to: ecs.Entity) void {
        if (from.hasLink(to)) {
            return;
        }

        from.getAvailableLink().* = to;
    }

    pub fn getRandomLink(self: *Waypoint, rand: std.Random) ecs.Entity {
        const l = self.len();
        const r = rand.uintLessThan(usize, l);

        return self.links[r].?;
    }

    pub fn len(self: *Waypoint) usize {
        var i: usize = 0;

        for (self.links) |maybeLink| {
            if (maybeLink) |_| {
                i += 1;
            } else {
                break;
            }
        }

        return i;
    }

    fn hasLink(self: *Waypoint, check: ecs.Entity) bool {
        for (self.links) |maybeLink| {
            if (maybeLink) |link| {
                if (link == check) {
                    return true;
                }
            }
        }

        return false;
    }

    fn getAvailableLink(self: *Waypoint) *?ecs.Entity {
        for (&self.links) |*maybeLink| {
            if (maybeLink.* == null) {
                return maybeLink;
            }
        }

        unreachable;
    }
};
