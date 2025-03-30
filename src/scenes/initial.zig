const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const rl = @import("raylib");
const zlm = @import("zlm");

const ecs = @import("ecs");

const zge = @import("zge");
const V = zge.vector.V;
const Vector = zge.vector.Vector;
const DrawSystem = zge.draw.DrawSystem;
const PhysicsSystem = zge.physics.PhysicsSystem;
const Screen = zge.screen.Screen;
const Collision = zge.physics.Collision;
const AABB = zge.physics.shape.AABB;
const Densities = zge.physics.Densities;
const Shape = zge.physics.shape.Shape;
const Rectangle = zge.physics.shape.Rectangle;

const Textures = @import("../textures.zig").Textures;
const Sounds = @import("../sounds.zig").Sounds;
const Music = @import("../music.zig").Music;

const Keybinds = @import("../input.zig").Keybinds;

const TextureComponent = zge.components.TextureComponent;
const AnimationComponent = @import("../components.zig").AnimationComponent;
const PedestrianAI = @import("../components.zig").PedestrianAI;
const LocationComponent = @import("../components.zig").LocationComponent;
const CustomerComponent = @import("../components.zig").CustomerComponent;
const Label = @import("../components.zig").Label;
const DropOffLocation = @import("../components.zig").DropOffLocation;
const RigidBody = @import("../components.zig").RigidBody;
const CarAI = @import("../car-ai.zig").CarAI;
const Waypoint = @import("../car-ai.zig").Waypoint;

const AnimationSystem = @import("../systems/animation.zig").AnimationSystem;
const PedestrianAISystem = @import("../systems/pedestrian-ai.zig").PedestrianAISystem;
const CustomerSystem = @import("../systems/customer.zig").CustomerSystem;
const CarAISystem = @import("../systems/car-ai.zig").CarAISystem;

const Highscore = @import("../highscore.zig").Highscore;

const animations = @import("../animations.zig");
const animation = @import("../animation.zig");
const Animation = animation.Animation;
const AnimationInstance = animation.AnimationInstance;

const Level = @import("../level.zig").Level;

const Camera = zge.camera.Camera;

const Direction = @import("../direction.zig").Direction;
const util = @import("../util.zig");

pub const LoadError = error{
    FailedLoading,
    AlreadyLoaded,
} || rl.RaylibError;

const NUMBER_OF_LEVELS = 5;
const NUMBER_OF_PEDESTRIANS = 50;

const carForce = 600000;
const brakeForce = carForce * 1.5;

const scale = 2;

const mapSize = V.init(896, 896);

const blockCellSize = 64 * scale;
const blockCellGridSize = 7;

const gameDuration = 120;

const boundaryPadding = V.scalar(64);
const boundariesTl = -boundaryPadding - V.scalar(blockCellGridSize - 1) * V.scalar(blockCellSize);
const boundariesBr = boundaryPadding + mapSize - V.scalar(blockCellSize / 2);
const boundary = AABB{
    .tl = boundariesTl,
    .br = boundariesBr,
    .isMinimal = true,
};

const humanCollisionBox = Shape{ .rectangle = Rectangle.init(V.init(0, 6), V.init(5, 7)) };
const carCollisionBox = Shape{ .rectangle = Rectangle.init(V.init(0, 0), V.init(28, 18)) };

const numberOfPedestrians = 50;

var rand = std.Random.DefaultPrng.init(1);

inline fn getRandomPosition() Vector {
    const x = rand.random().float(f32) * (boundary.right() - boundary.left()) + boundary.left();
    const y = rand.random().float(f32) * (boundary.bottom() - boundary.top()) + boundary.top();

    return V.init(x, y);
}

const InitialSceneState = union(enum) {
    playing,
    gameOver: GameOver,
    nextLevel,
    gameCompleted: GameCompleted,

    const GameOver = struct {
        placement: usize,
    };

    const GameCompleted = struct {
        placement: usize,
    };
};

pub const InitialScene = struct {
    reg: ecs.Registry,

    screen: *Screen,

    state: InitialSceneState,

    textures: Textures(rl.Texture2D) = undefined,
    sounds: Sounds(rl.Sound) = undefined,
    music: Music(rl.Music) = undefined,

    camera: Camera,
    fakeCamera: Camera,
    player: ecs.Entity = undefined,
    playerAnim1: *const rl.Texture2D = undefined,
    playerAnim2: *const rl.Texture2D = undefined,
    playerAnimLast: f64 = 0,
    engineSoundLast: f64 = 0,
    hardTurnSoundLast: f64 = 0,
    isBraking: bool = false,

    highscore: Highscore,

    score: usize = 100,
    timeLeft: f64 = gameDuration,
    levels: [NUMBER_OF_LEVELS]Level = .{
        Level.init(3),
        Level.init(4),
        Level.init(5),
        Level.init(6),
        Level.init(7),
    },
    currentLevel: usize = 0,

    houses: ecs.MultiView(2, 0) = undefined,

    keybinds: Keybinds = .{
        .up = rl.KeyboardKey.w,
        .down = rl.KeyboardKey.s,
        .left = rl.KeyboardKey.a,
        .right = rl.KeyboardKey.d,
        .brake = rl.KeyboardKey.space,
        .honk = rl.KeyboardKey.g,

        .restart = rl.KeyboardKey.space,
    },

    animationCarBlackLeft: *Animation,
    animationCarBlackRight: *Animation,
    animationCarBlackUp: *Animation,
    animationCarBlackDown: *Animation,

    animationCarRedLeft: *Animation,
    animationCarRedRight: *Animation,
    animationCarRedUp: *Animation,
    animationCarRedDown: *Animation,

    animationCarGreenLeft: *Animation,
    animationCarGreenRight: *Animation,
    animationCarGreenUp: *Animation,
    animationCarGreenDown: *Animation,

    animationCarWhiteLeft: *Animation,
    animationCarWhiteRight: *Animation,
    animationCarWhiteUp: *Animation,
    animationCarWhiteDown: *Animation,

    animationCarPurpleLeft: *Animation,
    animationCarPurpleRight: *Animation,
    animationCarPurpleUp: *Animation,
    animationCarPurpleDown: *Animation,

    animationPedestrianBlueWalk: *Animation,
    animationPedestrianRedWalk: *Animation,

    drawSystem: DrawSystem,
    physicsSystem: PhysicsSystem,
    animationSystem: AnimationSystem,

    allocator: Allocator,

    pub fn init(allocator: Allocator, screen: *Screen) InitialScene {
        return InitialScene{
            .reg = undefined,

            .state = .playing,

            .screen = screen,
            .camera = Camera.init(),
            .fakeCamera = Camera.init(),

            .animationCarBlackLeft = allocator.create(Animation) catch unreachable,
            .animationCarBlackRight = allocator.create(Animation) catch unreachable,
            .animationCarBlackUp = allocator.create(Animation) catch unreachable,
            .animationCarBlackDown = allocator.create(Animation) catch unreachable,

            .animationCarRedLeft = allocator.create(Animation) catch unreachable,
            .animationCarRedRight = allocator.create(Animation) catch unreachable,
            .animationCarRedUp = allocator.create(Animation) catch unreachable,
            .animationCarRedDown = allocator.create(Animation) catch unreachable,

            .animationCarGreenLeft = allocator.create(Animation) catch unreachable,
            .animationCarGreenRight = allocator.create(Animation) catch unreachable,
            .animationCarGreenUp = allocator.create(Animation) catch unreachable,
            .animationCarGreenDown = allocator.create(Animation) catch unreachable,

            .animationCarWhiteLeft = allocator.create(Animation) catch unreachable,
            .animationCarWhiteRight = allocator.create(Animation) catch unreachable,
            .animationCarWhiteUp = allocator.create(Animation) catch unreachable,
            .animationCarWhiteDown = allocator.create(Animation) catch unreachable,

            .animationCarPurpleLeft = allocator.create(Animation) catch unreachable,
            .animationCarPurpleRight = allocator.create(Animation) catch unreachable,
            .animationCarPurpleUp = allocator.create(Animation) catch unreachable,
            .animationCarPurpleDown = allocator.create(Animation) catch unreachable,

            .animationPedestrianBlueWalk = allocator.create(Animation) catch unreachable,
            .animationPedestrianRedWalk = allocator.create(Animation) catch unreachable,

            .highscore = undefined,

            .drawSystem = undefined,
            .physicsSystem = undefined,
            .animationSystem = AnimationSystem{},

            .allocator = allocator,
        };
    }

    pub fn deinit(scene: *InitialScene) void {
        scene.physicsSystem.deinit();
        scene.drawSystem.deinit();
        scene.animationCarBlackLeft.deinit(scene.allocator);
        scene.animationCarBlackRight.deinit(scene.allocator);
        scene.animationCarBlackUp.deinit(scene.allocator);
        scene.animationCarBlackDown.deinit(scene.allocator);
        scene.animationCarRedLeft.deinit(scene.allocator);
        scene.animationCarRedRight.deinit(scene.allocator);
        scene.animationCarRedUp.deinit(scene.allocator);
        scene.animationCarRedDown.deinit(scene.allocator);
        scene.animationCarGreenLeft.deinit(scene.allocator);
        scene.animationCarGreenRight.deinit(scene.allocator);
        scene.animationCarGreenUp.deinit(scene.allocator);
        scene.animationCarGreenDown.deinit(scene.allocator);
        scene.animationCarWhiteLeft.deinit(scene.allocator);
        scene.animationCarWhiteRight.deinit(scene.allocator);
        scene.animationCarWhiteUp.deinit(scene.allocator);
        scene.animationCarWhiteDown.deinit(scene.allocator);
        scene.animationCarPurpleLeft.deinit(scene.allocator);
        scene.animationCarPurpleRight.deinit(scene.allocator);
        scene.animationCarPurpleUp.deinit(scene.allocator);
        scene.animationCarPurpleDown.deinit(scene.allocator);
        scene.animationPedestrianBlueWalk.deinit(scene.allocator);
        scene.animationPedestrianRedWalk.deinit(scene.allocator);
        scene.allocator.destroy(scene.animationCarBlackLeft);
        scene.allocator.destroy(scene.animationCarBlackRight);
        scene.allocator.destroy(scene.animationCarBlackUp);
        scene.allocator.destroy(scene.animationCarBlackDown);
        scene.allocator.destroy(scene.animationCarRedLeft);
        scene.allocator.destroy(scene.animationCarRedRight);
        scene.allocator.destroy(scene.animationCarRedUp);
        scene.allocator.destroy(scene.animationCarRedDown);
        scene.allocator.destroy(scene.animationCarGreenLeft);
        scene.allocator.destroy(scene.animationCarGreenRight);
        scene.allocator.destroy(scene.animationCarGreenUp);
        scene.allocator.destroy(scene.animationCarGreenDown);
        scene.allocator.destroy(scene.animationCarWhiteLeft);
        scene.allocator.destroy(scene.animationCarWhiteRight);
        scene.allocator.destroy(scene.animationCarWhiteUp);
        scene.allocator.destroy(scene.animationCarWhiteDown);
        scene.allocator.destroy(scene.animationCarPurpleLeft);
        scene.allocator.destroy(scene.animationCarPurpleRight);
        scene.allocator.destroy(scene.animationCarPurpleUp);
        scene.allocator.destroy(scene.animationCarPurpleDown);
        scene.allocator.destroy(scene.animationPedestrianBlueWalk);
        scene.allocator.destroy(scene.animationPedestrianRedWalk);
        scene.highscore.deinit();
        scene.reg.deinit();
    }

    var isLoaded = false;
    pub fn load(s: *anyopaque, texturePaths: Textures([*:0]const u8), soundPaths: Sounds([*:0]const u8), musicPaths: Music([*:0]const u8)) LoadError!void {
        const scene: *InitialScene = @ptrCast(@alignCast(s));

        if (isLoaded) {
            return LoadError.AlreadyLoaded;
        }

        scene.loadHighscore();

        inline for (std.meta.fields(@TypeOf(texturePaths))) |field| {
            @field(scene.textures, field.name) = try rl.loadTexture(@field(texturePaths, field.name));
        }

        inline for (std.meta.fields(@TypeOf(soundPaths))) |field| {
            const sound = try rl.loadSound(@field(soundPaths, field.name));
            @field(scene.sounds, field.name) = sound;
            rl.setSoundVolume(sound, 0.05);
        }

        inline for (std.meta.fields(@TypeOf(musicPaths))) |field| {
            const music = try rl.loadMusicStream(@field(musicPaths, field.name));
            @field(scene.music, field.name) = music;
            rl.setMusicVolume(music, 1);
        }

        scene.playerAnim1 = &scene.textures.playerLeft1;
        scene.playerAnim2 = &scene.textures.playerLeft2;

        scene.animationCarBlackLeft.* = animations.carBlackLeftAnimation(scene.allocator, &scene.textures);
        scene.animationCarBlackRight.* = animations.carBlackRightAnimation(scene.allocator, &scene.textures);
        scene.animationCarBlackUp.* = animations.carBlackUpAnimation(scene.allocator, &scene.textures);
        scene.animationCarBlackDown.* = animations.carBlackDownAnimation(scene.allocator, &scene.textures);

        scene.animationCarRedLeft.* = animations.carRedLeftAnimation(scene.allocator, &scene.textures);
        scene.animationCarRedRight.* = animations.carRedRightAnimation(scene.allocator, &scene.textures);
        scene.animationCarRedUp.* = animations.carRedUpAnimation(scene.allocator, &scene.textures);
        scene.animationCarRedDown.* = animations.carRedDownAnimation(scene.allocator, &scene.textures);

        scene.animationCarGreenLeft.* = animations.carGreenLeftAnimation(scene.allocator, &scene.textures);
        scene.animationCarGreenRight.* = animations.carGreenRightAnimation(scene.allocator, &scene.textures);
        scene.animationCarGreenUp.* = animations.carGreenUpAnimation(scene.allocator, &scene.textures);
        scene.animationCarGreenDown.* = animations.carGreenDownAnimation(scene.allocator, &scene.textures);

        scene.animationCarWhiteLeft.* = animations.carWhiteLeftAnimation(scene.allocator, &scene.textures);
        scene.animationCarWhiteRight.* = animations.carWhiteRightAnimation(scene.allocator, &scene.textures);
        scene.animationCarWhiteUp.* = animations.carWhiteUpAnimation(scene.allocator, &scene.textures);
        scene.animationCarWhiteDown.* = animations.carWhiteDownAnimation(scene.allocator, &scene.textures);

        scene.animationCarPurpleLeft.* = animations.carPurpleLeftAnimation(scene.allocator, &scene.textures);
        scene.animationCarPurpleRight.* = animations.carPurpleRightAnimation(scene.allocator, &scene.textures);
        scene.animationCarPurpleUp.* = animations.carPurpleUpAnimation(scene.allocator, &scene.textures);
        scene.animationCarPurpleDown.* = animations.carPurpleDownAnimation(scene.allocator, &scene.textures);

        scene.animationPedestrianBlueWalk.* = animations.pedestrianBlueWalkAnimation(scene.allocator, &scene.textures);
        scene.animationPedestrianRedWalk.* = animations.pedestrianRedWalkAnimation(scene.allocator, &scene.textures);

        scene.start();

        isLoaded = true;
    }

    fn loadHighscore(scene: *InitialScene) void {
        scene.highscore = Highscore.loadHighscore(scene.allocator) catch |err| result: {
            std.log.err("Error loading highscores: {}", .{err});
            break :result Highscore{};
        };
    }

    fn restart(scene: *InitialScene) void {
        scene.physicsSystem.deinit();
        scene.drawSystem.deinit();
        scene.reg.deinit();

        scene.start();
    }

    fn start(scene: *InitialScene) void {
        scene.reg = ecs.Registry.init(scene.allocator);
        scene.physicsSystem = PhysicsSystem.init(scene.allocator, &scene.reg, boundary);
        scene.camera = Camera.init();
        scene.drawSystem = DrawSystem.init(scene.allocator, &scene.reg, scene.screen, &scene.fakeCamera);
        scene.drawSystem.bind();

        scene.reg.singletons().add(rand);

        const player = scene.initPlayer();

        scene.currentLevel = 0;
        scene.initLevel();

        scene.initHouseGrid(-1, -1);
        scene.initHouseGrid(-1, 0);
        scene.initHouseGrid(0, -1);
        scene.initHouseGrid(0, 0);

        scene.initBoundary();

        scene.player = player;
        scene.score = 0;
        scene.timeLeft = gameDuration;
        scene.state = .playing;
        scene.houses = scene.reg.view(.{ DropOffLocation, RigidBody }, .{});

        scene.initPedestrians();

        _ = scene.initCustomer();

        scene.initWaypointsAndCars();

        rl.playMusicStream(scene.music.theme);
    }

    fn clearLevel(scene: *InitialScene) void {
        const cars = scene.reg.basicView(CarAI);

        for (cars.data()) |entity| {
            scene.reg.removeAll(entity);
        }

        const pedestrians = scene.reg.basicView(PedestrianAI);

        for (pedestrians.data()) |entity| {
            scene.reg.removeAll(entity);
        }

        const customers = scene.reg.basicView(CustomerComponent);

        for (customers.data()) |entity| {
            scene.reg.removeAll(entity);
        }

        scene.reg.removeAll(scene.player);

        const waypoints = scene.reg.basicView(Waypoint);

        for (waypoints.data()) |entity| {
            scene.reg.removeAll(entity);
        }
    }

    fn progressToNextLevel(scene: *InitialScene) void {
        scene.currentLevel += 1;
        scene.setLevel(scene.currentLevel);
        scene.clearLevel();
        scene.player = scene.initPlayer();
        //scene.initWaypointsAndCars();
        scene.initPedestrians();
        _ = scene.initCustomer();
        scene.timeLeft = gameDuration;
        scene.state = .playing;
    }

    fn completeGame(scene: *InitialScene) void {
        scene.score += 500;
        scene.state = .{ .gameCompleted = .{ .placement = scene.highscore.scorePlacement(scene.score) } };
    }

    fn initLevel(scene: *InitialScene) void {
        scene.reg.singletons().add(scene.levels[0]);
    }

    fn getLevel(scene: *InitialScene) *Level {
        return scene.reg.singletons().get(Level);
    }

    fn setLevel(scene: *InitialScene, level: usize) void {
        scene.reg.singletons().get(Level).* = scene.levels[level];
    }

    pub fn initPlayer(scene: *InitialScene) ecs.Entity {
        const player = scene.reg.create();

        scene.reg.add(player, Label{ .label = "Player" });

        const pos = V.scalar(blockCellGridSize - 5) * V.scalar(blockCellSize);
        _ = scene.physicsSystem.addRigidBody(player, .{ .pos = pos, .scale = scale }, .{
            .shape = carCollisionBox,
            .density = Densities.Element.Iron,
            .restitution = 0.2,
            .isStatic = false,
        });

        scene.reg.add(player, TextureComponent.init(&scene.textures.playerRight1, null, V.zero));
        scene.reg.add(player, Direction{});

        return player;
    }

    fn initHouseGrid(scene: *InitialScene, x: f32, y: f32) void {
        const ox = x * blockCellGridSize - x;
        const oy = y * blockCellGridSize - y;

        _ = scene.initHouse(1 + ox, 1 + oy, &scene.textures.houseGreen);
        _ = scene.initHouse(3 + ox, 1 + oy, &scene.textures.houseBlue);
        _ = scene.initHouse(5 + ox, 1 + oy, &scene.textures.houseBlue);

        _ = scene.initHouse(1 + ox, 3 + oy, &scene.textures.houseOrange);
        _ = scene.initHouse(3 + ox, 3 + oy, &scene.textures.houseRed);
        _ = scene.initHouse(5 + ox, 3 + oy, &scene.textures.houseGreen);

        _ = scene.initHouse(1 + ox, 5 + oy, &scene.textures.houseRed);
        _ = scene.initHouse(3 + ox, 5 + oy, &scene.textures.houseBlue);
        _ = scene.initHouse(5 + ox, 5 + oy, &scene.textures.houseOrange);
    }

    const WaypointsAABB = struct {
        pub const tl = AABB{
            .tl = cityBlockSquaresIncludingRoads[0].tl,
            .br = cityBlockSquaresIncludingRoads[0].tl + V.scalar(blockCellSize),
            .isMinimal = true,
        };
        pub const l = AABB{
            .tl = cityBlockSquaresIncludingRoads[0].bl() + V.init(0, -blockCellSize),
            .br = cityBlockSquaresIncludingRoads[0].bl() + V.init(blockCellSize, 0),
            .isMinimal = true,
        };
        pub const bl = AABB{
            .tl = cityBlockSquaresIncludingRoads[1].bl() + V.init(0, -blockCellSize),
            .br = cityBlockSquaresIncludingRoads[1].bl() + V.init(blockCellSize, 0),
            .isMinimal = true,
        };
        pub const t = AABB{
            .tl = cityBlockSquaresIncludingRoads[0].tr() + V.init(-blockCellSize, 0),
            .br = cityBlockSquaresIncludingRoads[0].tr() + V.init(0, blockCellSize),
            .isMinimal = true,
        };
        pub const c = AABB{
            .tl = cityBlockSquaresIncludingRoads[0].br - V.scalar(blockCellSize),
            .br = cityBlockSquaresIncludingRoads[0].br,
            .isMinimal = true,
        };
        pub const b = AABB{
            .tl = cityBlockSquaresIncludingRoads[1].br - V.scalar(blockCellSize),
            .br = cityBlockSquaresIncludingRoads[1].br,
            .isMinimal = true,
        };
        pub const tr = AABB{
            .tl = cityBlockSquaresIncludingRoads[2].tr() + V.init(-blockCellSize, 0),
            .br = cityBlockSquaresIncludingRoads[2].tr() + V.init(0, blockCellSize),
            .isMinimal = true,
        };
        pub const r = AABB{
            .tl = cityBlockSquaresIncludingRoads[2].br - V.scalar(blockCellSize),
            .br = cityBlockSquaresIncludingRoads[2].br,
            .isMinimal = true,
        };
        pub const br = AABB{
            .tl = cityBlockSquaresIncludingRoads[3].br - V.scalar(blockCellSize),
            .br = cityBlockSquaresIncludingRoads[3].br,
            .isMinimal = true,
        };
    };

    const Intersections = struct {
        tl: IntersectionWaypoints,
        l: IntersectionWaypoints,
        bl: IntersectionWaypoints,
        t: IntersectionWaypoints,
        c: IntersectionWaypoints,
        b: IntersectionWaypoints,
        tr: IntersectionWaypoints,
        r: IntersectionWaypoints,
        br: IntersectionWaypoints,
    };

    fn initIntersections(scene: *InitialScene) Intersections {
        return Intersections{
            .tl = scene.initWaypointsForIntersection(
                WaypointsAABB.tl,
                .{ .tl = true, .br = true },
            ),
            .l = scene.initWaypointsForIntersection(WaypointsAABB.l, .{
                .tl = true,
                .tr = true,
                .bl = true,
                .br = true,
            }),
            .bl = scene.initWaypointsForIntersection(
                WaypointsAABB.bl,
                .{ .bl = true, .tr = true },
            ),
            .t = scene.initWaypointsForIntersection(WaypointsAABB.t, .{
                .tl = true,
                .tr = true,
                .bl = true,
                .br = true,
            }),
            .c = scene.initWaypointsForIntersection(WaypointsAABB.c, null),
            .b = scene.initWaypointsForIntersection(WaypointsAABB.b, .{
                .tl = true,
                .tr = true,
                .bl = true,
                .br = true,
            }),
            .tr = scene.initWaypointsForIntersection(
                WaypointsAABB.tr,
                .{
                    .tr = true,
                    .bl = true,
                },
            ),
            .r = scene.initWaypointsForIntersection(WaypointsAABB.r, .{
                .tl = true,
                .tr = true,
                .bl = true,
                .br = true,
            }),
            .br = scene.initWaypointsForIntersection(
                WaypointsAABB.br,
                .{
                    .br = true,
                    .tl = true,
                },
            ),
        };
    }

    fn addWaypoint(scene: *InitialScene, position: Vector) ecs.Entity {
        const entity = scene.reg.create();

        scene.reg.add(entity, Waypoint.init());
        _ = scene.physicsSystem.addRigidBody(entity, .{
            .pos = position,
        }, .{
            .shape = Shape{
                .rectangle = Rectangle.init(V.zero, WAYPOINT_SIZE),
            },
            .isStatic = true,
            .isSolid = false,
            .density = 1,
            .restitution = 0,
        });

        return entity;
    }

    const IntersectionInput = struct {
        tl: ?ecs.Entity = null,
        bl: ?ecs.Entity = null,
        br: ?ecs.Entity = null,
        tr: ?ecs.Entity = null,
    };

    const IntersectionWaypoints = struct {
        tl: ?ecs.Entity,
        bl: ?ecs.Entity,
        br: ?ecs.Entity,
        tr: ?ecs.Entity,

        pub fn connect(
            output: IntersectionWaypoints,
            input: IntersectionInput,
            scene: *InitialScene,
        ) void {
            if (input.bl) |in| {
                if (output.bl) |out| {
                    const wp = scene.reg.get(Waypoint, in);
                    wp.connect(out);
                }
            }

            if (input.tl) |in| {
                if (output.tl) |out| {
                    const wp = scene.reg.get(Waypoint, in);
                    wp.connect(out);
                }
            }

            if (input.tr) |in| {
                if (output.tr) |out| {
                    const wp = scene.reg.get(Waypoint, in);
                    wp.connect(out);
                }
            }

            if (input.br) |in| {
                if (output.br) |out| {
                    const wp = scene.reg.get(Waypoint, in);
                    wp.connect(out);
                }
            }
        }
    };
    const IntersectionConfiguration = struct {
        tl: bool = false,
        bl: bool = false,
        br: bool = false,
        tr: bool = false,
    };
    fn initWaypointsForIntersection(
        scene: *InitialScene,
        rect: AABB,
        configuration: ?IntersectionConfiguration,
    ) IntersectionWaypoints {
        const tlEnabled = if (configuration) |c| c.tl else true;
        const blEnabled = if (configuration) |c| c.bl else true;
        const brEnabled = if (configuration) |c| c.br else true;
        const trEnabled = if (configuration) |c| c.tr else true;

        const rUnit = (std.math.pi * 0.5);
        const unit = rect.size() * V.scalar(0.25);
        const c = rect.center();

        const tlRel = V.rotate(unit, rUnit * 2);
        const blRel = V.rotate(unit, rUnit);
        const brRel = unit;
        const trRel = V.rotate(unit, rUnit * 3);

        const tlPos = c + tlRel;
        const blPos = c + blRel;
        const brPos = c + brRel;
        const trPos = c + trRel;

        const tl = if (tlEnabled) scene.addWaypoint(tlPos) else null;
        const bl = if (blEnabled) scene.addWaypoint(blPos) else null;
        const br = if (brEnabled) scene.addWaypoint(brPos) else null;
        const tr = if (trEnabled) scene.addWaypoint(trPos) else null;

        const output = IntersectionWaypoints{
            .bl = bl,
            .tl = tl,
            .tr = tr,
            .br = br,
        };

        if (configuration == null) {
            const tlW = scene.reg.get(Waypoint, tl.?);
            const blW = scene.reg.get(Waypoint, bl.?);
            const brW = scene.reg.get(Waypoint, br.?);
            const trW = scene.reg.get(Waypoint, tr.?);

            tlW.connect(bl.?);
            blW.connect(br.?);
            brW.connect(tr.?);
            trW.connect(tl.?);
        }

        return output;
    }

    fn initWaypointsAndCars(scene: *InitialScene) void {
        const intersections = scene.initIntersections();

        const leftIntersectionEntryFromCenter = scene.addWaypoint(WaypointsAABB.l.tr() + WaypointsAABB.l.size() * V.scalar(0.25));
        const leftIntersectionEntryFromCenterWP = scene.reg.get(Waypoint, leftIntersectionEntryFromCenter);
        leftIntersectionEntryFromCenterWP.givePrecedenceTo = AABB{
            .tl = WaypointsAABB.l.tl + V.init(WaypointsAABB.l.width() * 0.5, 0),
            .br = WaypointsAABB.l.br + V.init(0, WaypointsAABB.l.height()),
            .isMinimal = true,
        };
        const leftIntersectionTlWP = scene.reg.get(Waypoint, intersections.l.tl.?);
        const leftIntersectionBlWP = scene.reg.get(Waypoint, intersections.l.bl.?);
        const leftIntersectionTrWP = scene.reg.get(Waypoint, intersections.l.tr.?);
        leftIntersectionTlWP.givePrecedenceTo = leftIntersectionEntryFromCenterWP.givePrecedenceTo;
        leftIntersectionTlWP.connect(intersections.l.br.?);

        const topIntersectionEntryFromCenter = scene.addWaypoint(WaypointsAABB.t.bc() + WaypointsAABB.t.size() * V.scalar(0.25));
        const topIntersectionEntryFromCenterWP = scene.reg.get(Waypoint, topIntersectionEntryFromCenter);
        topIntersectionEntryFromCenterWP.givePrecedenceTo = AABB{
            .tl = WaypointsAABB.t.tl + WaypointsAABB.t.size() * V.init(-1, 0.5),
            .br = WaypointsAABB.t.br,
            .isMinimal = true,
        };
        const topIntersectionTlWP = scene.reg.get(Waypoint, intersections.t.tl.?);
        const topIntersectionTrWP = scene.reg.get(Waypoint, intersections.t.tr.?);
        const topIntersectionBrWP = scene.reg.get(Waypoint, intersections.t.br.?);
        topIntersectionTrWP.givePrecedenceTo = topIntersectionEntryFromCenterWP.givePrecedenceTo;
        topIntersectionTrWP.connect(intersections.t.bl.?);

        const centerIntersectionTlW = scene.reg.get(Waypoint, intersections.c.tl.?);
        const centerIntersectionTrW = scene.reg.get(Waypoint, intersections.c.tr.?);
        const centerIntersectionBlW = scene.reg.get(Waypoint, intersections.c.bl.?);
        const centerIntersectionBrW = scene.reg.get(Waypoint, intersections.c.br.?);

        const bottomIntersectionEntryFromCenter = scene.addWaypoint(WaypointsAABB.b.tc() - WaypointsAABB.b.size() * V.scalar(0.25));
        const bottomIntersectionEntryFromCenterWP = scene.reg.get(Waypoint, bottomIntersectionEntryFromCenter);
        bottomIntersectionEntryFromCenterWP.givePrecedenceTo = AABB{
            .tl = WaypointsAABB.b.tl,
            .br = WaypointsAABB.b.br + WaypointsAABB.b.size() * V.init(1, -0.5),
            .isMinimal = true,
        };
        const bottomIntersectionBrWP = scene.reg.get(Waypoint, intersections.b.br.?);
        const bottomIntersectionTlWP = scene.reg.get(Waypoint, intersections.b.tl.?);
        const bottomIntersectionBlWP = scene.reg.get(Waypoint, intersections.b.bl.?);
        bottomIntersectionBlWP.givePrecedenceTo = bottomIntersectionEntryFromCenterWP.givePrecedenceTo;
        bottomIntersectionBlWP.connect(intersections.b.tr.?);

        const rightIntersectionEntryFromCenter = scene.addWaypoint(WaypointsAABB.r.bl() - WaypointsAABB.r.size() * V.scalar(0.25));
        const rightIntersectionEntryFromCenterWP = scene.reg.get(Waypoint, rightIntersectionEntryFromCenter);
        rightIntersectionEntryFromCenterWP.givePrecedenceTo = AABB{
            .tl = WaypointsAABB.r.tl - V.init(0, WaypointsAABB.r.height()),
            .br = WaypointsAABB.r.br - V.init(WaypointsAABB.r.width() * 0.5, 0),
            .isMinimal = true,
        };
        const rightIntersectionTrWP = scene.reg.get(Waypoint, intersections.r.tr.?);
        const rightIntersectionBrWP = scene.reg.get(Waypoint, intersections.r.br.?);
        const rightIntersectionBlWP = scene.reg.get(Waypoint, intersections.r.bl.?);
        rightIntersectionBrWP.givePrecedenceTo = rightIntersectionEntryFromCenterWP.givePrecedenceTo;
        rightIntersectionBrWP.connect(intersections.r.tl.?);

        intersections.tl.connect(.{
            .tl = intersections.tr.tr,
            .br = intersections.bl.tr,
        }, scene);

        intersections.l.connect(.{
            .tl = intersections.tl.tl,
            .br = intersections.bl.tr,
        }, scene);
        leftIntersectionBlWP.connect(intersections.bl.bl.?);
        leftIntersectionEntryFromCenterWP.connect(intersections.l.tr.?);
        leftIntersectionEntryFromCenterWP.connect(intersections.l.bl.?);
        leftIntersectionTrWP.connect(intersections.tl.br.?);

        intersections.bl.connect(.{
            .bl = intersections.tl.tl,
            .tr = intersections.br.tl,
        }, scene);

        intersections.t.connect(.{
            .tr = intersections.tr.tr,
            .bl = intersections.tl.bl,
        }, scene);
        topIntersectionTlWP.connect(intersections.tl.tl.?);
        topIntersectionEntryFromCenterWP.connect(intersections.t.br.?);
        topIntersectionEntryFromCenterWP.connect(intersections.t.tl.?);
        topIntersectionBrWP.connect(intersections.tr.bl.?);

        intersections.c.connect(.{
            .tl = intersections.t.bl,
            .bl = intersections.l.br,
            .br = intersections.b.tr,
            .tr = intersections.r.tl,
        }, scene);
        centerIntersectionTlW.connect(leftIntersectionEntryFromCenter);
        centerIntersectionTrW.connect(topIntersectionEntryFromCenter);
        centerIntersectionBlW.connect(bottomIntersectionEntryFromCenter);
        centerIntersectionBrW.connect(rightIntersectionEntryFromCenter);

        intersections.b.connect(.{
            .bl = intersections.bl.bl,
            .tr = intersections.br.tl,
        }, scene);
        bottomIntersectionBrWP.connect(intersections.br.br.?);
        bottomIntersectionEntryFromCenterWP.connect(intersections.b.tl.?);
        bottomIntersectionEntryFromCenterWP.connect(intersections.b.br.?);
        bottomIntersectionTlWP.connect(intersections.bl.tr.?);

        intersections.tr.connect(.{
            .tr = intersections.br.br,
            .bl = intersections.tl.br,
        }, scene);

        intersections.r.connect(.{
            .tl = intersections.tr.bl,
            .br = intersections.br.br,
        }, scene);
        rightIntersectionTrWP.connect(intersections.tr.tr.?);
        rightIntersectionEntryFromCenterWP.connect(intersections.r.bl.?);
        rightIntersectionEntryFromCenterWP.connect(intersections.r.tr.?);
        rightIntersectionBlWP.connect(intersections.br.tl.?);

        intersections.br.connect(.{
            .tl = intersections.tr.bl,
            .br = intersections.bl.bl,
        }, scene);

        const topLeftCarPos = V.init(
            -blockCellSize * blockCellGridSize + 512,
            -blockCellSize * blockCellGridSize + 128,
        );
        const topLeftCarPos2 = V.init(
            -blockCellSize * blockCellGridSize + 256,
            -blockCellSize * blockCellGridSize + 128,
        );
        const bottomRightCarPos = V.init(
            64,
            blockCellSize * (blockCellGridSize - 2) + 128,
        );
        const bottomRightCarPos2 = V.init(
            256,
            blockCellSize * (blockCellGridSize - 2) + 192,
        );
        const bottomLeftCarPos = V.init(
            -64,
            blockCellSize * (blockCellGridSize - 2) + 128,
        );
        const bottomLeftCarPos2 = V.init(
            -256,
            blockCellSize * (blockCellGridSize - 2) + 128,
        );

        _ = scene.initCar(topLeftCarPos, intersections.tl.tl.?);
        _ = scene.initCar(topLeftCarPos2, intersections.tl.tl.?);
        _ = scene.initCar(V.init(0, 0), intersections.c.bl.?);
        _ = scene.initCar(V.init(512, 64), intersections.r.bl.?);
        _ = scene.initCar(V.init(256, 64), intersections.r.bl.?);
        _ = scene.initCar(V.init(-512, 0), intersections.l.tr.?);
        _ = scene.initCar(V.init(-256, 0), intersections.l.tr.?);
        _ = scene.initCar(V.init(0, -256), intersections.t.br.?);
        _ = scene.initCar(V.init(0, -512), intersections.t.br.?);
        _ = scene.initCar(V.init(64, 256), intersections.c.br.?);
        _ = scene.initCar(V.init(0, 512), intersections.b.tl.?);
        _ = scene.initCar(bottomLeftCarPos, intersections.bl.bl.?);
        _ = scene.initCar(bottomLeftCarPos2, intersections.bl.tr.?);
        _ = scene.initCar(bottomRightCarPos, intersections.b.tr.?);
        _ = scene.initCar(bottomRightCarPos2, intersections.br.br.?);
    }

    pub fn initHouse(scene: *InitialScene, x: f32, y: f32, texture: *const rl.Texture2D) usize {
        const house = scene.reg.create();

        scene.reg.add(house, .{ .label = "House" });

        const w: f32 = if (texture == &scene.textures.houseOrange) 12 else 24;
        const h: f32 = 10;

        const textureSize = V.fromInt(i32, texture.width, texture.height);
        const pos = V.init(x, y) * V.scalar(128) + textureSize * V.scalar(0.5) + V.scalar(blockCellSize / 8);

        _ = scene.physicsSystem.addRigidBody(house, .{ .pos = pos, .scale = scale * 2 }, .{
            .shape = .{ .rectangle = Rectangle.init(V.init(0, 4), V.init(w, h)) },
            .isStatic = true,
            .restitution = 0,
            .density = Densities.Element.Iron,
        });

        const entrancePosition = pos + V.init(0, 64);
        scene.reg.add(house, LocationComponent{ .entrancePosition = entrancePosition });
        scene.reg.add(house, DropOffLocation{});

        scene.reg.add(house, TextureComponent.init(texture, null, V.zero));

        return house;
    }

    pub fn initBoundary(scene: *InitialScene) void {
        const boundaryLeft = scene.reg.create();
        const boundaryRight = scene.reg.create();
        const boundaryTop = scene.reg.create();
        const boundaryBottom = scene.reg.create();

        const xh = (boundary.bottom() - boundary.top()) / scale;

        const boundaryLeftPos = boundary.cl();

        _ = scene.physicsSystem.addRigidBody(boundaryLeft, .{ .pos = boundaryLeftPos, .scale = scale }, .{
            .shape = .{ .rectangle = Rectangle.init(V.init(0, 0), V.init(2, xh)) },
            .isStatic = true,
            .restitution = 0,
            .density = Densities.Element.Iron,
        });

        const boundaryRightPos = boundary.cr();

        _ = scene.physicsSystem.addRigidBody(boundaryRight, .{ .pos = boundaryRightPos, .scale = scale }, .{
            .shape = .{ .rectangle = Rectangle.init(V.init(0, 0), V.init(2, xh)) },
            .isStatic = true,
            .restitution = 0,
            .density = Densities.Element.Iron,
        });

        const yw = (boundary.right() - boundary.left()) / scale;

        const boundaryTopPos = boundary.tc();

        _ = scene.physicsSystem.addRigidBody(boundaryTop, .{ .pos = boundaryTopPos, .scale = scale }, .{
            .shape = .{ .rectangle = Rectangle.init(V.init(0, 0), V.init(yw, 6)) },
            .isStatic = true,
            .restitution = 0,
            .density = Densities.Element.Iron,
        });

        const boundaryBottomPos = boundary.bc();

        _ = scene.physicsSystem.addRigidBody(boundaryBottom, .{ .pos = boundaryBottomPos, .scale = scale }, .{
            .shape = .{ .rectangle = Rectangle.init(V.init(0, 0), V.init(yw, 6)) },
            .isStatic = true,
            .restitution = 0,
            .density = Densities.Element.Iron,
        });
    }

    fn initPedestrians(scene: *InitialScene) void {
        for (0..NUMBER_OF_PEDESTRIANS) |_| {
            _ = scene.initPedestrian(getRandomPosition());
        }
    }

    fn initPedestrian(scene: *InitialScene, position: Vector) usize {
        const pedestrian = scene.reg.create();

        scene.reg.add(pedestrian, .{ .label = "Pedestrian" });

        _ = scene.physicsSystem.addRigidBody(pedestrian, .{ .pos = position, .scale = scale }, .{
            .shape = humanCollisionBox,
            .isStatic = false,
            .restitution = 0,
            .density = Densities.Human,
        });

        const animationInstance = AnimationInstance.init(scene.animationPedestrianBlueWalk);
        scene.reg.add(pedestrian, AnimationComponent{ .animationInstance = animationInstance });

        scene.reg.add(pedestrian, TextureComponent.init(animationInstance.getCurrentTexture(), null, V.zero));

        scene.reg.add(pedestrian, PedestrianAI.init());

        return pedestrian;
    }

    fn initCustomer(scene: *InitialScene) ecs.Entity {
        const customer = scene.reg.create();

        scene.reg.add(customer, Label{ .label = "Customer" });

        const p = scene.getRandomDropOffLocation() + V.init(0, 32);

        _ = scene.physicsSystem.addRigidBody(customer, .{ .pos = p, .scale = scale }, .{
            .shape = humanCollisionBox,
            .isStatic = false,
            .isSolid = false,
            .restitution = 0,
            .density = Densities.Human,
        });

        var animationInstance = AnimationInstance.init(scene.animationPedestrianRedWalk);
        animationInstance.pause();
        scene.reg.add(customer, AnimationComponent{ .animationInstance = animationInstance });

        scene.reg.add(customer, TextureComponent.init(animationInstance.getCurrentTexture(), null, V.zero));

        scene.reg.add(customer, CustomerComponent{});

        return customer;
    }

    const CarAnimations = struct {
        pub fn black(scene: *InitialScene) CarAI.Animations {
            return .{
                .right = scene.animationCarBlackRight,
                .up = scene.animationCarBlackUp,
                .left = scene.animationCarBlackLeft,
                .down = scene.animationCarBlackDown,
            };
        }

        pub fn red(scene: *InitialScene) CarAI.Animations {
            return .{
                .right = scene.animationCarRedRight,
                .up = scene.animationCarRedUp,
                .left = scene.animationCarRedLeft,
                .down = scene.animationCarRedDown,
            };
        }

        pub fn green(scene: *InitialScene) CarAI.Animations {
            return .{
                .right = scene.animationCarGreenRight,
                .up = scene.animationCarGreenUp,
                .left = scene.animationCarGreenLeft,
                .down = scene.animationCarGreenDown,
            };
        }

        pub fn white(scene: *InitialScene) CarAI.Animations {
            return .{
                .right = scene.animationCarWhiteRight,
                .up = scene.animationCarWhiteUp,
                .left = scene.animationCarWhiteLeft,
                .down = scene.animationCarWhiteDown,
            };
        }

        pub fn purple(scene: *InitialScene) CarAI.Animations {
            return .{
                .right = scene.animationCarPurpleRight,
                .up = scene.animationCarPurpleUp,
                .left = scene.animationCarPurpleLeft,
                .down = scene.animationCarPurpleDown,
            };
        }

        const choices = .{ "black", "red", "green", "white", "purple" };

        pub fn random(scene: *InitialScene) CarAI.Animations {
            const len = std.meta.fields(@TypeOf(choices)).len;
            const i = rand.random().uintLessThan(usize, len);

            inline for (0..len) |j| {
                if (i == j) {
                    return @field(CarAnimations, choices[j])(scene);
                }
            }

            unreachable;
        }
    };

    fn initCar(
        scene: *InitialScene,
        position: Vector,
        targetWaypoint: ecs.Entity,
    ) usize {
        const car = scene.reg.create();

        _ = scene.physicsSystem.addRigidBody(car, .{ .pos = position, .scale = scale }, .{
            .shape = carCollisionBox,
            .isStatic = false,
            .restitution = 0.2,
            .density = Densities.Element.Iron,
        });
        scene.reg.add(car, CarAI.init(Direction.LEFT, targetWaypoint, CarAnimations.random(scene)));
        const ai = scene.reg.get(CarAI, car);

        var animationInstance = AnimationInstance.init(ai.animations.right);
        scene.reg.add(car, AnimationComponent{ .animationInstance = animationInstance });
        scene.reg.add(car, TextureComponent.init(animationInstance.getCurrentTexture(), null, V.zero));

        return car;
    }

    fn getRandomDropOffLocation(scene: *InitialScene) Vector {
        var len: usize = 0;
        var it = scene.houses.entityIterator();

        while (it.next()) |_| {
            len += 1;
        }

        std.debug.assert(len > 0);

        var i = rand.random().intRangeLessThan(usize, 0, len);

        it.reset();

        const house = while (it.next()) |entity| {
            if (i == 0) {
                break entity;
            }
            i -= 1;
        } else {
            unreachable;
        };

        return scene.houses.get(RigidBody, house).d.clonePos();
    }

    fn onCollision(scene: *InitialScene, event: Collision) void {
        _ = event; // autofix
        _ = scene; // autofix
        //        if ((event.entityA == context.scene.player or event.entityB == context.scene.player) and !rl.isSoundPlaying(context.reg.sounds.crash)) {
        //            rl.playSound(context.reg.sounds.crash);
        //        }
    }

    pub fn update(s: *anyopaque, dt: f32, t: f64) void {
        const scene: *InitialScene = @ptrCast(@alignCast(s));

        rl.updateMusicStream(scene.music.theme);

        scene.handleInput();

        if (scene.state == .nextLevel) {
            return;
        }

        CarAISystem.updateCarFriction(scene.reg.get(RigidBody, scene.player), scene.reg.get(Direction, scene.player));
        scene.updatePhysics(dt);
        scene.clampPedestriansInsideCityBlocks();
        scene.updateAnimationAndSound(t);
        PedestrianAISystem.update(scene.allocator, &scene.reg, &scene.physicsSystem, scene.player, &scene.textures, t);
        CustomerSystem.update(&scene.reg, scene.player);
        CarAISystem.update(scene.allocator, &scene.reg, &scene.physicsSystem);
        scene.updateCamera();
        scene.updateTimeLeft(dt);

        if (scene.state == .playing) {
            scene.addMissingCustomer();
        }
    }

    fn updateTimeLeft(scene: *InitialScene, dt: f32) void {
        if (scene.state == .playing) {
            scene.timeLeft -= dt;
        }

        if (scene.timeLeft <= 0 and scene.state == .playing) {
            scene.timeLeft = 0;
            scene.state = .{ .gameOver = .{ .placement = scene.highscore.scorePlacement(scene.score) } };
            scene.highscore.insertHighscoreIfEligible(scene.score) catch |err| {
                std.log.err("Error inserting highscore: {}", .{err});
            };
        }
    }

    fn addMissingCustomer(scene: *InitialScene) void {
        if (scene.reg.len(CustomerComponent) > 0) return;

        _ = scene.initCustomer();

        scene.score += 100;
        const level = scene.getLevel();
        level.deliveredCustomers += 1;
        rl.playSound(scene.sounds.score);

        if (level.isLevelComplete()) {
            const isAtLastLevel = scene.currentLevel >= NUMBER_OF_LEVELS - 1;

            if (isAtLastLevel) {
                scene.completeGame();
            } else {
                scene.state = .nextLevel;
            }
        }
    }

    fn updatePhysics(scene: *InitialScene, dt: f32) void {
        scene.physicsSystem.update(dt);
        scene.physicsSystem.pollCollisions(*InitialScene, scene, onCollision);
    }

    fn isOnRoad(body: *RigidBody) bool {
        const isInBlockTL = !isInBlockNonRoad(body.aabb, V.init(-1, -1));
        const isInBlockTR = !isInBlockNonRoad(body.aabb, V.init(-1, 0));
        const isInBlockBL = !isInBlockNonRoad(body.aabb, V.init(0, -1));
        const isInBlockBR = !isInBlockNonRoad(body.aabb, V.init(0, 0));

        return isInBlockTL or isInBlockTR or isInBlockBL or isInBlockBR;
    }

    fn isInBlockNonRoad(checkAabb: AABB, blockGridPosition: Vector) bool {
        const blockSquareRect = getBlockSquareRect(blockGridPosition);

        return checkAabb.intersects(blockSquareRect);
    }

    inline fn getBlockSquareRect(blockGridPosition: Vector) AABB {
        const blockSize = blockCellGridSize * 2;
        const gridPositionOffset = blockGridPosition * V.scalar(-2);

        const blockMin = blockGridPosition * V.scalar(blockSize) + gridPositionOffset;
        const offset = blockMin * V.scalar(0.5 * blockCellSize);
        const margin = 8;

        const tl = offset + V.scalar(blockCellSize * 0.75 + margin);

        return AABB{
            .tl = tl,
            .br = tl + V.scalar(blockCellSize * 5 - margin * 2),
            .isMinimal = true,
        };
    }

    fn getBlockSquareRectIncludingRoads(blockGridPosition: Vector) AABB {
        const blockSize = blockCellGridSize;

        const blockMin = blockGridPosition * V.scalar(blockSize);
        const spacing = V.scalar(blockCellSize) * blockGridPosition;

        const tl = blockMin * V.scalar(blockCellSize) - spacing - V.scalar(blockCellSize * 0.25);

        return AABB{
            .tl = tl,
            .br = tl + V.scalar(blockCellSize * blockCellGridSize),
            .isMinimal = true,
        };
    }

    fn updateAnimationAndSound(scene: *InitialScene, t: f64) void {
        const texture = scene.reg.get(TextureComponent, scene.player);
        const body = scene.reg.get(RigidBody, scene.player);

        const v = @abs(body.d.cloneVel());
        const a = @abs(body.d.cloneAccel());
        const proportionalVelocity = (V.x(v) + V.y(v)) / 200;

        const playerAnimSpeed = animations.carAnimSpeed(v);
        const shouldPlayHardTurnSound = (V.x(a) > 0 and V.y(v) > 75) or (V.y(a) > 0 and V.x(v) > 75);
        const engineSoundScale = @min(@max(proportionalVelocity + 0.5, 0.75), 3);

        if (scene.playerAnimLast < t - playerAnimSpeed) {
            if (texture.texture == scene.playerAnim1) {
                texture.texture = scene.playerAnim2;
            } else {
                texture.texture = scene.playerAnim1;
            }
            scene.playerAnimLast = t;

            if (scene.engineSoundLast < t - 0.43 / engineSoundScale) {
                rl.playSound(scene.sounds.engine);
                scene.engineSoundLast = t;
            }

            rl.setSoundPitch(scene.sounds.engine, engineSoundScale);
        }

        if (shouldPlayHardTurnSound and scene.hardTurnSoundLast < t - 0.2) {
            rl.playSound(scene.sounds.hardTurn);
            scene.hardTurnSoundLast = t;
        }

        scene.animationSystem.update(&scene.reg, t);
    }

    fn updateCamera(scene: *InitialScene) void {
        const body = scene.reg.get(RigidBody, scene.player);
        scene.camera.position = -body.d.clonePos();
    }

    pub fn handleInput(scene: *InitialScene) void {
        switch (scene.state) {
            .gameOver => {
                if (rl.isKeyDown(scene.keybinds.restart)) {
                    scene.restart();
                }
                return;
            },
            .gameCompleted => {
                if (rl.isKeyDown(scene.keybinds.restart)) {
                    scene.restart();
                }
                return;
            },
            .nextLevel => {
                if (rl.isKeyDown(scene.keybinds.restart)) {
                    scene.progressToNextLevel();
                }
                return;
            },
            else => {},
        }

        var f = V.zero;

        const body = scene.reg.get(RigidBody, scene.player);
        const direction = scene.reg.get(Direction, scene.player);

        if (rl.isKeyDown(scene.keybinds.left)) {
            V.setX(&f, -carForce);
            scene.playerAnim1 = &scene.textures.playerLeft1;
            scene.playerAnim2 = &scene.textures.playerLeft2;
            direction.setLeft();
        } else if (rl.isKeyDown(scene.keybinds.right)) {
            V.setX(&f, carForce);
            scene.playerAnim1 = &scene.textures.playerRight1;
            scene.playerAnim2 = &scene.textures.playerRight2;
            direction.setRight();
        } else if (rl.isKeyDown(scene.keybinds.up)) {
            V.setY(&f, -carForce);
            scene.playerAnim1 = &scene.textures.playerUp1;
            scene.playerAnim2 = &scene.textures.playerUp2;
            direction.setUp();
        } else if (rl.isKeyDown(scene.keybinds.down)) {
            V.setY(&f, carForce);
            scene.playerAnim1 = &scene.textures.playerDown1;
            scene.playerAnim2 = &scene.textures.playerDown2;
            direction.setDown();
        }

        if (rl.isKeyDown(scene.keybinds.brake)) {
            f = V.normalize(-body.d.cloneVel()) * V.scalar(brakeForce);
            scene.isBraking = true;
        } else {
            scene.isBraking = false;
        }

        if (rl.isKeyDown(scene.keybinds.honk) and !rl.isSoundPlaying(scene.sounds.horn)) {
            rl.playSound(scene.sounds.horn);
        }

        body.applyForce(f);
    }

    fn applyCarTurningFriction(scene: *InitialScene) void {
        const body = scene.reg.get(RigidBody, scene.player);
        const a = body.d.cloneAccel();
        const v = body.d.cloneVel();
        const direction = scene.reg.get(Direction, scene.player);

        const tireStickFriction = 0.5;
        const tireStickFrictionWhileSliding = 0.1;
        const slideThreshold = 300;
        const turnTransferVelocityFactor = 0.5;
        const turnTransferVelocityFactorWhileSliding = 0;

        // Calculate steepness of turn
        const perpendicular = a.rotate(std.math.pi / @as(f32, 2)).normalize();
        const vm = v.dot(perpendicular);
        const steepness = @max(@abs(vm) - slideThreshold, 0);

        const turningForceMagnitude: f32 = if (steepness > 0) tireStickFrictionWhileSliding else tireStickFriction;

        // Turning physics, makes car "lock in" when making a turn
        const f = V.init(
            if (direction.isVertical()) -v.x * turningForceMagnitude else 0,
            if (direction.isHorizontal()) -v.y * turningForceMagnitude else 0,
        );

        // Bring some of the velocity from the old direction into the new direction
        // so that we don't lose as much velocity when turning

        const turnKeepVelocityFactor: f32 = if (steepness > 0) turnTransferVelocityFactorWhileSliding else turnTransferVelocityFactor;
        const b = V.init(@abs(f.y) * std.math.sign(a.x), @abs(f.x) * std.math.sign(a.y)).scale(turnKeepVelocityFactor);

        body.applyForce(f.add(b));
    }

    const BlockConnections = struct {
        left: bool = false,
        top: bool = false,
        right: bool = false,
        bottom: bool = false,
    };

    fn drawBlock(scene: *const InitialScene, blockGridPosition: Vector, connections: BlockConnections) void {
        const blockSize = blockCellGridSize * 2;
        const gridPositionOffset = blockGridPosition * V.scalar(-2);

        const blockMin = blockGridPosition * V.scalar(blockSize) + gridPositionOffset;
        const blockMax = blockMin + V.scalar(blockSize - 2);
        const edgeRoadsLength = 10;

        // Parks
        const pixelOffset = blockMin * V.scalar(0.5 * blockCellSize) + V.scalar(blockCellSize / 4);
        const park1Position = pixelOffset + V.scalar(blockCellSize) * V.init(3, 2);
        const park2Position = pixelOffset + V.scalar(blockCellSize) * V.init(3, 4);
        scene.drawSystem.drawTextureSRWithCamera(&scene.textures.park, null, V.zero, park1Position, 0, scale * 2, false);
        scene.drawSystem.drawTextureSRWithCamera(&scene.textures.park, null, V.zero, park2Position, 0, scale * 2, false);

        // Top Road
        scene.drawRoad(blockMin + V.init(2, 0), RoadDirection.Right, edgeRoadsLength);
        // Bottom Road
        scene.drawRoad(blockMax + V.init(-1, 0), RoadDirection.Left, edgeRoadsLength);
        // Left Road
        scene.drawRoad(blockMin + V.init(0, 2), RoadDirection.Down, edgeRoadsLength);
        // Right Road
        scene.drawRoad(blockMax + V.init(0, -1), RoadDirection.Up, edgeRoadsLength);

        // Top Left
        if (connections.left and !connections.top) {
            scene.drawTIntersectionHorizontalDown(blockMin);
        } else if (!connections.left and connections.top) {
            scene.drawTIntersectionVerticalRight(blockMin);
        } else if (connections.left and connections.top) {
            scene.drawIntersection(blockMin);
        } else {
            scene.drawTurnFromDownToRight(blockMin);
        }

        // Top Right
        const trp = V.init(V.x(blockMax), V.y(blockMin));
        if (connections.right and !connections.top) {
            scene.drawTIntersectionHorizontalDown(trp);
        } else if (!connections.right and connections.top) {
            scene.drawTIntersectionVerticalLeft(trp);
        } else if (connections.right and connections.top) {
            scene.drawIntersection(trp);
        } else {
            scene.drawTurnFromLeftToDown(trp);
        }

        // Bottom Left
        const blp = V.init(V.x(blockMin), V.y(blockMax));
        if (connections.left and !connections.bottom) {
            scene.drawTIntersectionHorizontalUp(blp);
        } else if (!connections.left and connections.bottom) {
            scene.drawTIntersectionVerticalRight(blp);
        } else if (connections.left and connections.bottom) {
            scene.drawIntersection(blp);
        } else {
            scene.drawTurnFromUpToRight(blp);
        }

        // Bottom Right
        if (connections.right and !connections.bottom) {
            scene.drawTIntersectionHorizontalUp(blockMax);
        } else if (!connections.right and connections.bottom) {
            scene.drawTIntersectionVerticalLeft(blockMax);
        } else if (connections.right and connections.bottom) {
            scene.drawIntersection(blockMax);
        } else {
            scene.drawTurnFromLeftToUp(blockMax);
        }
    }

    const roadSize: f32 = 32;
    pub const RoadDirection = enum { Up, Down, Left, Right };

    fn roadSourceRectTr(gp: Vector) AABB {
        return AABB{
            .tl = gp * V.scalar(32 + 4 + 1) + V.scalar(2),
            .br = gp * V.scalar(32 + 4 + 1) + V.scalar(2 + 32),
            .isMinimal = true,
        };
    }

    const roadSourceRects = struct {
        pub const up = roadSourceRectTr(V.init(2, 2));
        pub const down = roadSourceRectTr(V.init(0, 3));
        pub const right = roadSourceRectTr(V.init(1, 3));
        pub const left = roadSourceRectTr(V.init(2, 3));
        pub const intersectionTopLeft = roadSourceRectTr(V.init(4, 3));
        pub const intersectionTopRight = roadSourceRectTr(V.init(3, 3));
        pub const intersectionBottomLeft = roadSourceRectTr(V.init(4, 2));
        pub const intersectionBottomRight = roadSourceRectTr(V.init(3, 2));
        pub const cornerTopLeft = roadSourceRectTr(V.init(3, 0));
        pub const cornerTopRight = roadSourceRectTr(V.init(4, 0));
        pub const cornerBottomLeft = roadSourceRectTr(V.init(3, 1));
        pub const cornerBottomRight = roadSourceRectTr(V.init(4, 1));
    };

    pub fn drawRoad(scene: *const InitialScene, p0: Vector, direction: RoadDirection, length: usize) void {
        var pA = p0;
        var pB = p0;
        var d: f32 = 1;
        var textureA: AABB = undefined;
        var textureB: AABB = undefined;

        if (direction == RoadDirection.Left or direction == RoadDirection.Right) {
            pB += V.init(0, 1);
            textureA = roadSourceRects.up;
            textureB = roadSourceRects.down;
        } else {
            pB += V.init(1, 0);
            textureA = roadSourceRects.left;
            textureB = roadSourceRects.right;
        }

        if (direction == RoadDirection.Left or direction == RoadDirection.Up) {
            d = -1;
        }

        for (0..length) |_| {
            const pAs = pA * V.scalar(32 * scale);
            const pBs = pB * V.scalar(32 * scale);

            scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, textureA, V.zero, pAs, 0, scale, false);
            scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, textureB, V.zero, pBs, 0, scale, false);

            std.log.debug("drawing road at: {d} {d}", .{ pAs, pBs });

            if (direction == RoadDirection.Left or direction == RoadDirection.Right) {
                pA += V.init(d, 0);
                pB += V.init(d, 0);
            } else if (direction == RoadDirection.Up or direction == RoadDirection.Down) {
                pA += V.init(0, d);
                pB += V.init(0, d);
            }
        }
    }

    const RoadConfigurationPositions = struct {
        tl: Vector,
        tr: Vector,
        bl: Vector,
        br: Vector,
    };

    fn getRoadConfigurationPositions(position: Vector) RoadConfigurationPositions {
        const step = 32 * scale;

        const tl = position * V.scalar(step);
        const tr = tl + V.init(step, 0);
        const bl = (position + V.init(0, 1)) * V.scalar(step);
        const br = bl + V.init(step, 0);

        return .{ .tl = tl, .tr = tr, .bl = bl, .br = br };
    }

    pub fn drawIntersection(scene: *const InitialScene, position: Vector) void {
        const positions = getRoadConfigurationPositions(position);

        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.intersectionTopLeft, V.zero, positions.tl, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.intersectionTopRight, V.zero, positions.tr, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.intersectionBottomLeft, V.zero, positions.bl, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.intersectionBottomRight, V.zero, positions.br, 0, scale, false);
    }

    pub fn drawTurnFromDownToRight(scene: *const InitialScene, position: Vector) void {
        const positions = getRoadConfigurationPositions(position);

        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.cornerTopLeft, V.zero, positions.tl, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.up, V.zero, positions.tr, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.left, V.zero, positions.bl, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.intersectionBottomRight, V.zero, positions.br, 0, scale, false);
    }

    pub fn drawTurnFromUpToRight(scene: *const InitialScene, position: Vector) void {
        const positions = getRoadConfigurationPositions(position);

        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.left, V.zero, positions.tl, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.intersectionTopRight, V.zero, positions.tr, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.cornerBottomLeft, V.zero, positions.bl, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.down, V.zero, positions.br, 0, scale, false);
    }

    pub fn drawTurnFromLeftToUp(scene: *const InitialScene, position: Vector) void {
        const positions = getRoadConfigurationPositions(position);

        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.intersectionTopLeft, V.zero, positions.tl, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.right, V.zero, positions.tr, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.down, V.zero, positions.bl, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.cornerBottomRight, V.zero, positions.br, 0, scale, false);
    }

    pub fn drawTurnFromLeftToDown(scene: *const InitialScene, position: Vector) void {
        const positions = getRoadConfigurationPositions(position);

        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.up, V.zero, positions.tl, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.cornerTopRight, V.zero, positions.tr, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.intersectionBottomLeft, V.zero, positions.bl, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.right, V.zero, positions.br, 0, scale, false);
    }

    pub fn drawTIntersectionHorizontalUp(scene: *const InitialScene, position: Vector) void {
        const positions = getRoadConfigurationPositions(position);

        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.intersectionTopLeft, V.zero, positions.tl, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.intersectionTopRight, V.zero, positions.tr, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.down, V.zero, positions.bl, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.down, V.zero, positions.br, 0, scale, false);
    }

    pub fn drawTIntersectionHorizontalDown(scene: *const InitialScene, position: Vector) void {
        const positions = getRoadConfigurationPositions(position);

        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.up, V.zero, positions.tl, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.up, V.zero, positions.tr, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.intersectionBottomLeft, V.zero, positions.bl, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.intersectionBottomRight, V.zero, positions.br, 0, scale, false);
    }

    pub fn drawTIntersectionVerticalLeft(scene: *const InitialScene, position: Vector) void {
        const positions = getRoadConfigurationPositions(position);

        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.intersectionTopLeft, V.zero, positions.tl, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.right, V.zero, positions.tr, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.intersectionBottomLeft, V.zero, positions.bl, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.right, V.zero, positions.br, 0, scale, false);
    }

    pub fn drawTIntersectionVerticalRight(scene: *const InitialScene, position: Vector) void {
        const positions = getRoadConfigurationPositions(position);

        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.left, V.zero, positions.tl, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.intersectionTopRight, V.zero, positions.tr, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.left, V.zero, positions.bl, 0, scale, false);
        scene.drawSystem.drawTextureSR(&scene.textures.roadTileset, roadSourceRects.intersectionBottomRight, V.zero, positions.br, 0, scale, false);
    }

    fn drawTopFences(scene: *const InitialScene) void {
        const xStep: f32 = @as(f32, @floatFromInt(scene.textures.fenceY.width)) * scale;

        const xSteps = @as(usize, @intFromFloat(@divFloor((boundary.right() - boundary.left()), xStep)));

        // Top
        for (1..xSteps) |i| {
            const if32 = @as(f32, @floatFromInt(i));
            const p = V.init(boundary.left() + if32 * xStep, boundary.top());
            scene.drawSystem.drawTextureSRWithCamera(&scene.textures.fenceY, null, V.zero, p, 0, scale, false);
        }

        // Top Left
        scene.drawSystem.drawTextureSRWithCamera(&scene.textures.fenceTopLeft, null, V.zero, V.init(boundary.left(), boundary.top()), 0, scale, false);
        // Top Right
        scene.drawSystem.drawTextureSRWithCamera(&scene.textures.fenceTopRight, null, V.zero, V.init(boundary.right(), boundary.top()), 0, scale, false);
    }

    fn drawBottomAndSideFences(scene: *const InitialScene) void {
        const xStep: f32 = @as(f32, @floatFromInt(scene.textures.fenceY.width)) * scale;
        const yStep: f32 = @as(f32, @floatFromInt(scene.textures.fenceX.height)) * scale;

        const xSteps = @as(usize, @intFromFloat(@divFloor((boundary.right() - boundary.left()), xStep)));
        const ySteps = @as(usize, @intFromFloat(@divFloor((boundary.bottom() - boundary.top()), yStep)));

        // Bottom
        for (1..xSteps) |i| {
            const if32 = @as(f32, @floatFromInt(i));
            const x = boundary.left() + if32 * xStep;
            const y = boundary.bottom();
            scene.drawSystem.drawTextureSRWithCamera(&scene.textures.fenceY, null, V.zero, V.init(x, y), 0, scale, false);
        }

        // Left and Right
        for (1..ySteps) |i| {
            const if32 = @as(f32, @floatFromInt(i));

            const xl = boundary.left();
            const yl = boundary.top() + if32 * yStep;
            scene.drawSystem.drawTextureSRWithCamera(&scene.textures.fenceX, null, V.zero, V.init(xl, yl), 0, scale, false);

            const xr = boundary.right();
            const yr = boundary.top() + if32 * yStep;
            scene.drawSystem.drawTextureSRWithCamera(&scene.textures.fenceX, null, V.zero, V.init(xr, yr), 0, scale, false);
        }

        // Bottom Left
        scene.drawSystem.drawTextureSRWithCamera(&scene.textures.fenceBottomLeft, null, V.zero, V.init(boundary.left(), boundary.bottom()), 0, scale, false);
        // Bottom Right
        scene.drawSystem.drawTextureSRWithCamera(&scene.textures.fenceBottomRight, null, V.zero, V.init(boundary.right(), boundary.bottom()), 0, scale, false);
    }

    pub fn draw(s: *anyopaque, _: f32, _: f64) void {
        var scene: *InitialScene = @ptrCast(@alignCast(s));

        rl.beginDrawing();

        rl.clearBackground(rl.Color.init(0x82, 0x82, 0x82, 0xff));

        rl.beginMode2D(.{
            .zoom = 1,
            .offset = V.toRl(V.zero),
            .target = V.toRl(-scene.camera.position),
            .rotation = 0,
        });

        scene.drawBlock(V.init(-1, -1), .{ .right = true, .bottom = true });
        scene.drawBlock(V.init(0, -1), .{ .left = true, .bottom = true });
        scene.drawBlock(V.init(-1, 0), .{ .right = true, .top = true });
        scene.drawBlock(V.init(0, 0), .{ .left = true, .top = true });

        scene.drawTopFences();

        scene.drawDropOffLocation();

        scene.drawSystem.draw();

        //scene.drawDebugAvoidingCar();

        scene.drawBottomAndSideFences();

        //scene.drawDebugBlockSquare();
        //scene.drawDebugBlockSquareIncludingRoads();
        //scene.drawDebugWaypoints();
        //scene.drawDebugCarAI();

        scene.drawTargetArrow();

        rl.endMode2D();

        scene.drawScore();
        scene.drawTimeLeft();
        scene.drawDeliveredCustomers();

        switch (scene.state) {
            .gameOver => scene.drawGameOver(),
            .nextLevel => scene.drawNextLevel(),
            .gameCompleted => scene.drawGameCompleted(),
            else => {},
        }

        rl.drawFPS(@intFromFloat(V.x(scene.screen.size) - 100), 5);

        rl.endDrawing();
    }

    const WAYPOINT_SIZE_N = blockCellSize / 6;
    const WAYPOINT_SIZE = V.scalar(WAYPOINT_SIZE_N);

    fn screenPos(scene: *InitialScene, v: Vector) Vector {
        return scene.screen.screenPositionV(v);
        //return scene.screen.screenPositionV(scene.camera.transformV(v));
    }

    fn drawDebugWaypoints(scene: *InitialScene) void {
        var view = scene.reg.view(.{ RigidBody, Waypoint }, .{});
        var it = view.entityIterator();
        const ai = scene.reg.basicView(CarAI).raw()[0];

        while (it.next()) |entity| {
            const waypoint = view.get(Waypoint, entity);
            const body = view.get(RigidBody, entity);
            const aabb = body.aabb;

            const aabbColor = if (ai.waypoint == entity) rl.Color.red else rl.Color.blue;
            scene.drawSystem.drawAabb(aabb, aabbColor, 2);

            for (waypoint.links) |maybeLink| {
                if (maybeLink) |linkEntity| {
                    const linkBody = view.get(RigidBody, linkEntity);
                    const startPos = scene.screenPos(aabb.center());
                    const endPos = scene.screenPos(linkBody.aabb.center());
                    const arrowUnit = startPos.sub(endPos).normalize();
                    const padding = arrowUnit.scale(WAYPOINT_SIZE_N / 2);
                    const arrowStart = startPos.sub(padding);
                    const arrowEnd = endPos.add(padding);

                    const color = rl.Color.white;

                    rl.drawLineEx(V.toRl(arrowStart), V.toRl(arrowEnd), 2, color);

                    const arrowFlapBase = arrowUnit.scale(16);
                    const arrow1 = arrowFlapBase.rotate(std.math.pi / @as(f32, 4)).add(endPos).add(padding);
                    const arrow2 = arrowFlapBase.rotate(-std.math.pi / @as(f32, 4)).add(endPos).add(padding);

                    rl.drawLineEx(V.toRl(arrowEnd), V.toRl(arrow1), 2, color);
                    rl.drawLineEx(V.toRl(arrowEnd), V.toRl(arrow2), 2, color);
                }
            }

            if (waypoint.givePrecedenceTo) |rect| {
                const p = scene.screenPos(rect.tl);

                rl.drawRectangleLinesEx(.{ .x = p.x, .y = p.y, .width = rect.width(), .height = rect.height() }, 2, rl.Color.blue);
            }
        }
    }

    fn drawDebugCarAI(scene: *InitialScene) void {
        var view = scene.reg.view(.{ CarAI, RigidBody }, .{});
        var it = view.entityIterator();

        while (it.next()) |entity| {
            const body = view.get(RigidBody, entity);
            const ai = view.get(CarAI, entity);
            const sac = CarAISystem.getSafetyAwarenessCircle(body, ai);
            const sacRight = CarAISystem.getSafetyAwarenessCircleRight(body, ai);

            const p = scene.screenPos(sac.offset);
            rl.drawCircleLinesV(V.toRl(p), sac.radius, rl.Color.red);
            const pRight = scene.screenPos(sacRight.offset);
            rl.drawCircleLinesV(
                V.toRl(pRight),
                sacRight.radius,
                if (@import("../systems/car-ai.zig").carSafetyAwarenessRightEnabled) rl.Color.green else rl.Color.gray,
            );

            const wp = scene.reg.get(RigidBody, ai.waypoint);
            const wpP = scene.screenPos(wp.aabb.center());
            rl.drawLineV(V.toRl(scene.screenPos(body.aabb.center())), V.toRl(wpP), rl.Color.red);
        }
    }

    fn drawDebugAvoidingCar(scene: *InitialScene) void {
        var view = scene.reg.view(.{ PedestrianAI, RigidBody }, .{});
        var it = view.entityIterator();
        while (it.next()) |e| {
            const ai = scene.reg.getConst(PedestrianAI, e);
            const body = scene.reg.getConst(RigidBody, e);

            const p = scene.camera.transformV(scene.screen.screenPositionV(body.aabb.tl));

            const color = if (ai.state == .avoiding) rl.Color.red else rl.Color.green;
            rl.drawRectangleLinesEx(.{
                .x = p.x,
                .y = p.y,
                .width = body.aabb.width(),
                .height = body.aabb.height(),
            }, 1, color);
        }

        const avoidanceAABB = PedestrianAISystem.getPedestrianAvoidCarAABB(&scene.reg, scene.player);
        const avoidanceAABBp = scene.camera.transformV(
            scene.screen.screenPositionV(avoidanceAABB.tl),
        );

        rl.drawRectangleLinesEx(.{
            .x = avoidanceAABBp.x,
            .y = avoidanceAABBp.y,
            .width = avoidanceAABB.width(),
            .height = avoidanceAABB.height(),
        }, 1, rl.Color.yellow);
    }

    fn drawTextCenter(
        font: rl.Font,
        text: [*:0]const u8,
        position: Vector,
        fontSize: f32,
        spacing: f32,
        tint: rl.Color,
    ) void {
        const textSize = rl.measureTextEx(font, text, fontSize, spacing);
        const pos = V.fromRl(textSize) * V.scalar(-0.5) + position;
        rl.drawTextEx(font, text, V.toRl(pos), fontSize, spacing, tint);
    }

    fn drawGameOver(scene: *const InitialScene) void {
        const gameOverPos = scene.screen.size / V.init(2, 3);
        const instructionsPos = V.init(V.x(scene.screen.sizeHalf), V.y(gameOverPos) + 128);

        drawTextCenter(rl.getFontDefault() catch unreachable, "Game Over", gameOverPos, 96, 8, rl.Color.white);
        drawTextCenter(rl.getFontDefault() catch unreachable, "Press SPACE to restart", instructionsPos, 32, 2, rl.Color.white);

        const highscoreColors = [_]rl.Color{
            rl.Color.yellow,
            rl.Color.light_gray,
            rl.Color.brown,
        };

        const placement = scene.state.gameOver.placement;
        const placementNumberText = if (placement == 1) "1st" else if (placement == 2) "2nd" else "3rd";
        if (placement == 0) {
            // Didn't get highscore
        } else {
            const placementText = "You've got " ++ placementNumberText ++ " place!";

            drawTextCenter(
                rl.getFontDefault() catch unreachable,
                placementText,
                scene.screen.sizeHalf + V.init(0, 128),
                32,
                2,
                highscoreColors[placement - 1],
            );
        }

        var highscoreBuffer: [64:0]u8 = undefined;
        for (0..scene.highscore.leaderboard.len) |i| {
            const highscoreLabel = if (i == 0) "1st" else if (i == 1) "2nd" else "3rd";
            const highscoreText = std.fmt.bufPrint(&highscoreBuffer, "{s}. {d}", .{ highscoreLabel, scene.highscore.leaderboard[i].score }) catch |err| {
                std.log.err("Error printing: {}", .{err});
                return;
            };
            highscoreBuffer[highscoreText.len] = 0;

            const p = scene.screen.sizeHalf + V.init(
                0,
                128 + 96 + @as(f32, @floatFromInt(i)) * 36,
            );
            drawTextCenter(rl.getFontDefault() catch unreachable, &highscoreBuffer, p, 32, 2, highscoreColors[i]);
        }
    }

    fn drawNextLevel(scene: *const InitialScene) void {
        const firstTextPos = scene.screen.size / V.init(2, 3);
        const secondTextPos = V.init(V.x(scene.screen.sizeHalf), V.y(firstTextPos) + 128);

        drawTextCenter(rl.getFontDefault() catch unreachable, "Level Completed", firstTextPos, 96, 8, rl.Color.white);
        drawTextCenter(rl.getFontDefault() catch unreachable, "Press SPACE to go to the next level", secondTextPos, 32, 2, rl.Color.white);
    }

    fn drawGameCompleted(scene: *const InitialScene) void {
        const firstTextPos = scene.screen.size / V.init(2, 3);
        const secondTextPos = V.init(V.x(scene.screen.sizeHalf), V.y(firstTextPos) + 128);

        drawTextCenter(rl.getFontDefault() catch unreachable, "Congratulations", firstTextPos, 96, 8, rl.Color.fromHSV(@floatCast(rl.getTime() * 60), 1, 1));
        drawTextCenter(rl.getFontDefault() catch unreachable, "Game completed! Press SPACE to play again", secondTextPos, 32, 2, rl.Color.white);
    }

    fn drawScore(scene: *const InitialScene) void {
        var buffer: [64:0]u8 = undefined;
        const slice = std.fmt.bufPrint(&buffer, "{d}", .{scene.score}) catch |err| {
            std.log.err("Error printing score: {}", .{err});
            return;
        };
        buffer[slice.len] = 0;

        rl.drawText(&buffer, 5, 5, 32, rl.Color.white);
    }

    fn timeLeftPos(scene: *const InitialScene) Vector {
        return V.init((V.x(scene.screen.size) - 96) / 2, 5);
    }
    fn drawTimeLeft(scene: *const InitialScene) void {
        var buffer: [8:0]u8 = undefined;
        const slice = std.fmt.bufPrint(&buffer, "{d:.2}s", .{scene.timeLeft}) catch |err| {
            std.log.err("Error printing: {}", .{err});
            return;
        };
        buffer[slice.len] = 0;

        const color = if (scene.timeLeft == 0) rl.Color.red else rl.Color.white;

        rl.drawTextEx(rl.getFontDefault() catch unreachable, &buffer, V.toRl(scene.timeLeftPos()), 48, 2, color);
    }

    fn drawDeliveredCustomers(scene: *InitialScene) void {
        const level = scene.getLevel();
        var buffer: [3:0]u8 = undefined;
        const slice = std.fmt.bufPrint(&buffer, "{d}/{d}", .{ level.deliveredCustomers, level.numberOfCustomersToDeliver }) catch |err| {
            std.log.err("Error printing: {}", .{err});
            return;
        };
        buffer[slice.len] = 0;

        const m = V.fromRl(rl.measureTextEx(rl.getFontDefault() catch unreachable, &buffer, 40, 2));

        const marginRight = 8;
        const iconWidth = 32;
        const iconPadding = 4;
        const textPadding = 8;
        const rectWidth = iconWidth + iconPadding * 2 + textPadding * 2 + V.x(m);

        const p = scene.timeLeftPos() + V.init(-(rectWidth + marginRight), 2);
        const s = V.init(rectWidth - marginRight, 42);
        rl.drawRectangleRec(V.rect(p, s), rl.Color.white);

        const textPos = p + V.init(iconPadding * 2 + iconWidth, 4);
        rl.drawTextEx(rl.getFontDefault() catch unreachable, &buffer, V.toRl(textPos), 40, 2, rl.Color.black);

        const iconPos = p + V.init(iconPadding, 4);
        rl.drawTextureEx(scene.textures.pedestrianRedIdle, V.toRl(iconPos), 0, scale, rl.Color.white);
    }

    fn drawDropOffLocation(scene: *InitialScene) void {
        const view = scene.reg.basicView(CustomerComponent);

        for (view.raw()) |customer| {
            switch (customer.state) {
                .transportingToDropOff => |dropOff| {
                    const size = V.init(72, 48);
                    const p = scene.screenPos(dropOff.destination - size * V.scalar(0.5));
                    rl.drawRectangleV(V.toRl(p), V.toRl(size), rl.Color.green);
                },
                else => continue,
            }
        }
    }

    const cityBlockSquares: []const AABB = &.{
        getBlockSquareRect(V.init(-1, -1)),
        getBlockSquareRect(V.init(-1, 0)),
        getBlockSquareRect(V.init(0, -1)),
        getBlockSquareRect(V.init(0, 0)),
    };

    const cityBlockSquaresIncludingRoads: []const AABB = &.{
        getBlockSquareRectIncludingRoads(V.init(-1, -1)),
        getBlockSquareRectIncludingRoads(V.init(-1, 0)),
        getBlockSquareRectIncludingRoads(V.init(0, -1)),
        getBlockSquareRectIncludingRoads(V.init(0, 0)),
    };

    fn clampPedestriansInsideCityBlocks(scene: *InitialScene) void {
        var view = scene.reg.view(.{ RigidBody, PedestrianAI }, .{});
        var it = view.entityIterator();

        while (it.next()) |entity| {
            scene.clampPedestrianInsideCityBlocks(entity);
        }
    }

    fn clampPedestrianInsideCityBlocks(scene: *InitialScene, entity: ecs.Entity) void {
        const body = scene.reg.get(RigidBody, entity);

        if (!isOnRoad(body)) return;

        const bodyCenter = body.aabb.center();

        var minIndex: usize = 0;
        var minDist = std.math.inf(f32);

        for (0.., cityBlockSquares) |i, block| {
            const dist = V.distance(block.center(), bodyCenter);

            if (dist < minDist) {
                minDist = dist;
                minIndex = i;
            }
        }

        const targetBlock = cityBlockSquares[minIndex];

        body.d.setPos(std.math.clamp(body.d.clonePos(), targetBlock.tl, targetBlock.br));
    }

    fn drawDebugBlockSquare(scene: *const InitialScene) void {
        for (cityBlockSquares) |square| {
            const p = scene.screenPos(square.tl);

            rl.drawRectangleV(V.toRl(p), rl.Vector2.init(square.width(), square.height()), rl.Color.white);
        }
    }

    fn drawDebugBlockSquareIncludingRoads(scene: *const InitialScene) void {
        for (cityBlockSquaresIncludingRoads) |square| {
            const p = scene.screenPos(square.tl);

            rl.drawRectangleV(V.toRl(p), rl.Vector2.init(square.width(), square.height()), rl.Color.white);
        }
    }

    fn drawTargetArrow(scene: *InitialScene) void {
        const target = scene.getTargetPosition() orelse return;
        const body = scene.reg.getConst(RigidBody, scene.player);
        //const source = rl.Vector2.init(scene.camera.rect.x.rect.y);
        const source = body.d.clonePos();

        const screenEdgePosition = scene.getTargetScreenEdgePosition(target, source) orelse return;
        const arrowPosition = scene.screenPos(screenEdgePosition);

        const d = target - source;
        const r = std.math.radiansToDegrees(std.math.atan2(V.y(d), V.x(d)));

        const arrowSize = V.fromInt(
            c_int,
            scene.textures.targetArrow.width,
            scene.textures.targetArrow.height,
        );
        const sourceT = V.rect(V.zero, arrowSize);
        const dest = V.rect(arrowPosition, V.scalar(64));
        const origin = rl.Vector2.init(0, 0);

        rl.drawTexturePro(
            scene.textures.targetArrow,
            sourceT,
            dest,
            origin,
            r,
            rl.Color.red,
        );
    }

    fn getTargetScreenEdgePosition(scene: *const InitialScene, target: Vector, source: Vector) ?Vector {
        const sizeHalf = (scene.camera.size - V.scalar(128)) * V.scalar(0.5);
        const tl = V.toRl(source - sizeHalf);
        const br = V.toRl(source + sizeHalf);
        const tr = rl.Vector2.init(br.x, tl.y);
        const bl = rl.Vector2.init(tl.x, br.y);

        var collisionPoint: rl.Vector2 = undefined;

        const src = V.toRl(source);
        const tgt = V.toRl(target);

        // Top
        if (rl.checkCollisionLines(src, tgt, tl, tr, &collisionPoint)) {}
        // Left
        else if (rl.checkCollisionLines(src, tgt, tl, bl, &collisionPoint)) {}
        // Bottom
        else if (rl.checkCollisionLines(src, tgt, bl, br, &collisionPoint)) {}
        // Right
        else if (rl.checkCollisionLines(src, tgt, tr, br, &collisionPoint)) {} else {
            return null;
        }

        return V.fromRl(collisionPoint);
    }

    fn getTargetPosition(scene: *InitialScene) ?Vector {
        var view = scene.reg.basicView(CustomerComponent);

        for (view.data()) |entity| {
            const customer = view.getConst(entity);
            switch (customer.state) {
                .waitingForTransport => {
                    const body = scene.reg.getConst(RigidBody, entity);
                    return body.d.clonePos();
                },
                .walkingToDropOff => |dropOff| return dropOff.destination,
                .transportingToDropOff => |dropOff| return dropOff.destination,
            }
        }

        return null;
    }
};
