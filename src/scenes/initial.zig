const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const rl = @import("raylib");
const zlm = @import("zlm");

const ecs = @import("ecs");

const zge = @import("zge");
const DrawSystem = zge.draw.DrawSystem;
const PhysicsSystem = zge.physics.PhysicsSystem;
const Screen = zge.screen.Screen;
const CollisionEvent = zge.physics.CollisionEvent;
const AABB = zge.physics.shape.AABB;

const Textures = @import("../textures.zig").Textures;
const Sounds = @import("../sounds.zig").Sounds;

const Keybinds = @import("../input.zig").Keybinds;

const TextureComponent = zge.components.TextureComponent;
const AnimationComponent = @import("../components.zig").AnimationComponent;
const RandomWalk = @import("../components.zig").RandomWalk;
const LocationComponent = @import("../components.zig").LocationComponent;
const CustomerComponent = @import("../components.zig").CustomerComponent;
const Label = @import("../components.zig").Label;
const DropOffLocation = @import("../components.zig").DropOffLocation;
const RigidBody = @import("../components.zig").RigidBody;

const AnimationSystem = @import("../systems/animation.zig").AnimationSystem;
const RandomWalkSystem = @import("../systems/random-walk.zig").RandomWalkSystem;
const CustomerSystem = @import("../systems/customer.zig").CustomerSystem;

const Highscore = @import("../highscore.zig").Highscore;

const animations = @import("../animations.zig");
const animation = @import("../animation.zig");
const Animation = animation.Animation;
const AnimationInstance = animation.AnimationInstance;

const Camera = zge.camera.Camera;

const cfg = @import("../config.zig");
const initialSize = cfg.initialSize;

pub const LoadError = error{
    FailedLoading,
    AlreadyLoaded,
};

const playerSpeed = 1000;

const scale = 2;

const blockCellSize = 64 * scale;
const blockCellGridSize = 7;

const boundaryPadding = 64;
const boundaries = .{
    .l = -boundaryPadding - (blockCellGridSize - 1) * blockCellSize,
    .r = initialSize.w + boundaryPadding - blockCellSize / 2,
    .t = -boundaryPadding - (blockCellGridSize - 1) * blockCellSize,
    .b = initialSize.h + boundaryPadding - blockCellSize / 2,
};
const boundary = AABB{
    .tl = zlm.vec2(boundaries.l, boundaries.t),
    .br = zlm.vec2(boundaries.r, boundaries.b),
    .isMinimal = true,
};

const humanCollisionBox = zge.physics.shape.Shape{ .rectangle = zge.physics.shape.Rectangle.init(zlm.vec2(0, 6), zlm.vec2(5, 7)) };
const carCollisionBox = zge.physics.shape.Shape{ .rectangle = zge.physics.shape.Rectangle.init(zlm.vec2(0, 0), zlm.vec2(28, 18)) };

const numberOfPedestrians = 3000;

var rand = std.Random.DefaultPrng.init(1);

inline fn getRandomPosition() zlm.Vec2 {
    const x = rand.random().float(f32) * (boundaries.r - boundaries.l) + boundaries.l;
    const y = rand.random().float(f32) * (boundaries.b - boundaries.t) + boundaries.t;

    return zlm.vec2(x, y);
}

const InitialSceneState = union(enum) {
    playing,
    gameOver: GameOver,

    const GameOver = struct {
        placement: usize,
    };
};

pub const InitialScene = struct {
    reg: ecs.Registry,

    screen: *Screen,

    state: InitialSceneState,

    textures: Textures(rl.Texture2D) = undefined,
    sounds: Sounds(rl.Sound) = undefined,

    camera: Camera,
    player: ecs.Entity = undefined,
    playerAnim1: *const rl.Texture2D = undefined,
    playerAnim2: *const rl.Texture2D = undefined,
    playerAnimLast: f64 = 0,
    engineSoundLast: f64 = 0,
    hardTurnSoundLast: f64 = 0,
    isBraking: bool = false,

    highscore: Highscore,

    score: usize = 100,
    timeLeft: f64 = 60,

    houses: ecs.MultiView(2, 0) = undefined,

    keybinds: Keybinds = .{
        .up = rl.KeyboardKey.key_w,
        .down = rl.KeyboardKey.key_s,
        .left = rl.KeyboardKey.key_a,
        .right = rl.KeyboardKey.key_d,
        .brake = rl.KeyboardKey.key_space,
        .honk = rl.KeyboardKey.key_g,

        .restart = rl.KeyboardKey.key_space,
    },

    animationPedestrianBlueWalk: *Animation,
    animationPedestrianRedWalk: *Animation,

    drawSystem: DrawSystem,
    physicsSystem: PhysicsSystem,
    animationSystem: AnimationSystem,

    allocator: Allocator,

    pub fn init(allocator: Allocator, screen: *Screen) InitialScene {
        return InitialScene{
            .reg = ecs.Registry.init(allocator),

            .state = .playing,

            .screen = screen,
            .camera = Camera.init(),

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
        scene.animationPedestrianBlueWalk.deinit(scene.allocator);
        scene.animationPedestrianRedWalk.deinit(scene.allocator);
        scene.allocator.destroy(scene.animationPedestrianBlueWalk);
        scene.allocator.destroy(scene.animationPedestrianRedWalk);
        scene.highscore.deinit();
        scene.reg.deinit();
    }

    var isLoaded = false;
    pub fn load(s: *anyopaque, texturePaths: Textures([*:0]const u8), soundPaths: Sounds([*:0]const u8)) LoadError!void {
        const scene: *InitialScene = @ptrCast(@alignCast(s));

        if (isLoaded) {
            return LoadError.AlreadyLoaded;
        }

        scene.drawSystem = DrawSystem.init(scene.allocator, &scene.reg, scene.screen);
        scene.physicsSystem = PhysicsSystem.init(scene.allocator, &scene.reg, boundary);

        scene.drawSystem.bind();

        scene.reg.singletons().add(rand);

        scene.highscore = Highscore.loadHighscore(scene.allocator) catch |err| result: {
            std.log.err("Error loading highscores: {}", .{err});
            break :result Highscore{};
        };

        inline for (std.meta.fields(@TypeOf(texturePaths))) |field| {
            @field(scene.textures, field.name) = rl.loadTexture(@field(texturePaths, field.name));
        }

        inline for (std.meta.fields(@TypeOf(soundPaths))) |field| {
            const sound = rl.loadSound(@field(soundPaths, field.name));
            @field(scene.sounds, field.name) = sound;
            rl.setSoundVolume(sound, 0.05);
        }

        scene.playerAnim1 = &scene.textures.playerLeft1;
        scene.playerAnim2 = &scene.textures.playerLeft2;

        scene.animationPedestrianBlueWalk.* = animations.pedestrianBlueWalkAnimation(scene.allocator, &scene.textures);
        scene.animationPedestrianRedWalk.* = animations.pedestrianRedWalkAnimation(scene.allocator, &scene.textures);

        scene.player = scene.initPlayer();

        scene.houses = scene.reg.view(.{ DropOffLocation, RigidBody }, .{});

        scene.initHouseGrid(-1, -1);
        scene.initHouseGrid(-1, 0);
        scene.initHouseGrid(0, -1);
        scene.initHouseGrid(0, 0);

        scene.initBoundary();

        for (0..numberOfPedestrians) |_| {
            _ = scene.initPedestrian(getRandomPosition());
        }

        _ = scene.initCustomer();

        _ = scene.initCar();

        isLoaded = true;
    }

    pub fn initPlayer(scene: *InitialScene) ecs.Entity {
        const player = scene.reg.create();

        scene.reg.add(player, Label{ .label = "Player" });

        const pos = zlm.vec2(
            (-blockCellGridSize + 1) * blockCellSize,
            (-blockCellGridSize + 1) * blockCellSize,
        );
        _ = scene.physicsSystem.addRigidBody(player, .{ .pos = pos, .scale = scale }, .{
            .shape = carCollisionBox,
            .density = zge.physics.Densities.Element.Iron,
            .restitution = 0.2,
            .isStatic = false,
        });

        scene.reg.add(player, TextureComponent.init(&scene.textures.playerLeft1));

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

    pub fn initHouse(scene: *InitialScene, x: f32, y: f32, texture: *const rl.Texture2D) usize {
        const house = scene.reg.create();

        scene.reg.add(house, .{ .label = "House" });

        //const l: f32 = if (texture == &scene.textures.houseOrange) 10 else 4;
        const w: f32 = if (texture == &scene.textures.houseOrange) 12 else 24;
        //const t: f32 = 10;
        const h: f32 = 10;

        const pos = zlm.vec2(128 * x, 128 * y).add(zge.vector.fromInt(i32, texture.width, texture.height).scale(0.5)).add(zlm.Vec2.all(blockCellSize / 8));

        _ = scene.physicsSystem.addRigidBody(house, .{ .pos = pos, .scale = scale * 2 }, .{
            .shape = .{ .rectangle = zge.physics.shape.Rectangle.init(zlm.vec2(0, 4), zlm.vec2(w, h)) },
            .isStatic = true,
            .restitution = 0,
            .density = zge.physics.Densities.Element.Iron,
        });

        const entrancePosition = zlm.vec2(
            pos.x + 64,
            pos.y + 128,
        );
        scene.reg.add(house, LocationComponent{ .entrancePosition = entrancePosition });
        scene.reg.add(house, DropOffLocation{});

        scene.reg.add(house, TextureComponent.init(texture));

        return house;
    }

    pub fn initBoundary(scene: *InitialScene) void {
        const boundaryLeft = scene.reg.create();
        const boundaryRight = scene.reg.create();
        const boundaryTop = scene.reg.create();
        const boundaryBottom = scene.reg.create();

        const xh = (boundaries.b - boundaries.t) / scale;

        const boundaryLeftPos = boundary.cl();

        _ = scene.physicsSystem.addRigidBody(boundaryLeft, .{ .pos = boundaryLeftPos, .scale = scale }, .{
            .shape = .{ .rectangle = zge.physics.shape.Rectangle.init(zlm.vec2(0, 0), zlm.vec2(2, xh)) },
            .isStatic = true,
            .restitution = 0,
            .density = zge.physics.Densities.Element.Iron,
        });

        const boundaryRightPos = boundary.cr();

        _ = scene.physicsSystem.addRigidBody(boundaryRight, .{ .pos = boundaryRightPos, .scale = scale }, .{
            .shape = .{ .rectangle = zge.physics.shape.Rectangle.init(zlm.vec2(0, 0), zlm.vec2(2, xh)) },
            .isStatic = true,
            .restitution = 0,
            .density = zge.physics.Densities.Element.Iron,
        });

        const yw = (boundaries.r - boundaries.l) / scale;

        const boundaryTopPos = boundary.tc();

        _ = scene.physicsSystem.addRigidBody(boundaryTop, .{ .pos = boundaryTopPos, .scale = scale }, .{
            .shape = .{ .rectangle = zge.physics.shape.Rectangle.init(zlm.vec2(0, 0), zlm.vec2(yw, 6)) },
            .isStatic = true,
            .restitution = 0,
            .density = zge.physics.Densities.Element.Iron,
        });

        const boundaryBottomPos = boundary.bc();

        _ = scene.physicsSystem.addRigidBody(boundaryBottom, .{ .pos = boundaryBottomPos, .scale = scale }, .{
            .shape = .{ .rectangle = zge.physics.shape.Rectangle.init(zlm.vec2(0, 0), zlm.vec2(yw, 6)) },
            .isStatic = true,
            .restitution = 0,
            .density = zge.physics.Densities.Element.Iron,
        });
    }

    fn initPedestrian(scene: *InitialScene, position: zlm.Vec2) usize {
        const pedestrian = scene.reg.create();

        scene.reg.add(pedestrian, .{ .label = "Pedestrian" });

        _ = scene.physicsSystem.addRigidBody(pedestrian, .{ .pos = position, .scale = scale }, .{
            .shape = humanCollisionBox,
            .isStatic = false,
            .restitution = 0,
            .density = zge.physics.Densities.Human,
        });

        //        scene.reg.add(pedestrian, Physics{
        //            .cr = rl.Rectangle.init(2, 6, 9, 7),
        //            .f = 1,
        //            .isSolid = true,
        //        });

        const animationInstance = AnimationInstance.init(scene.animationPedestrianBlueWalk);
        scene.reg.add(pedestrian, AnimationComponent{ .animationInstance = animationInstance });

        scene.reg.add(pedestrian, TextureComponent.init(animationInstance.getCurrentTexture()));

        scene.reg.add(pedestrian, RandomWalk.init());

        return pedestrian;
    }

    fn initCustomer(scene: *InitialScene) ecs.Entity {
        const customer = scene.reg.create();

        scene.reg.add(customer, Label{ .label = "Customer" });

        var p = scene.getRandomDropOffLocation();
        p.x += 64;
        p.y += 96;

        _ = scene.physicsSystem.addRigidBody(customer, .{ .pos = p, .scale = scale }, .{
            .shape = humanCollisionBox,
            .isStatic = false,
            .restitution = 0,
            .density = zge.physics.Densities.Human,
        });
        //        scene.reg.add(customer, Physics{
        //            .cr = rl.Rectangle.init(2, 6, 9, 7),
        //            .f = 1,
        //        });

        var animationInstance = AnimationInstance.init(scene.animationPedestrianRedWalk);
        animationInstance.pause();
        scene.reg.add(customer, AnimationComponent{ .animationInstance = animationInstance });

        scene.reg.add(customer, TextureComponent.init(animationInstance.getCurrentTexture()));

        scene.reg.add(customer, CustomerComponent{});

        return customer;
    }

    fn initCar(
        scene: *InitialScene,
    ) usize {
        const x = 0;
        const y = -blockCellSize * blockCellGridSize + 128;

        const car = scene.reg.create();

        _ = scene.physicsSystem.addRigidBody(car, .{ .pos = zlm.vec2(x, y), .scale = scale }, .{
            .shape = carCollisionBox,
            .isStatic = false,
            .restitution = 0.2,
            .density = zge.physics.Densities.Element.Iron,
        });
        scene.reg.add(car, TextureComponent.init(&scene.textures.carBlackLeft1));

        return car;
    }

    fn getRandomDropOffLocation(scene: *InitialScene) zlm.Vec2 {
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

    const EventHandlerContext = struct { scene: *InitialScene, reg: *ecs.Registry };

    fn onCollision(_: *InitialScene, _: CollisionEvent) void {
        //fn onCollision(context: *EventHandlerContext, event: CollisionEvent) void {
        //        if ((event.entityA == context.scene.player or event.entityB == context.scene.player) and !rl.isSoundPlaying(context.reg.sounds.crash)) {
        //            rl.playSound(context.reg.sounds.crash);
        //        }
    }

    pub fn update(s: *anyopaque, dt: f32, t: f64) void {
        const scene: *InitialScene = @ptrCast(@alignCast(s));

        scene.handleInput(dt);
        scene.updatePhysics(dt);
        scene.updateCarFriction(dt);
        scene.updateAnimationAndSound(t);
        //RandomWalkSystem.update(&scene.reg, &scene.textures, t);
        //CustomerSystem.update(&scene.reg, scene.player);
        scene.updateCamera();
        scene.updateTimeLeft(dt);

        //scene.addMissingCustomer();
    }

    fn restart(scene: *InitialScene) void {
        scene.reg.deinit();
        scene.reg = ecs.Registry.init(scene.allocator);
        scene.physicsSystem.deinit();
        scene.physicsSystem = PhysicsSystem.init(scene.allocator, &scene.reg, boundary);
        scene.drawSystem.deinit();
        scene.drawSystem = DrawSystem.init(scene.allocator, &scene.reg, scene.screen);
        scene.drawSystem.bind();

        const player = scene.initPlayer();

        scene.initHouseGrid(-1, -1);
        scene.initHouseGrid(-1, 0);
        scene.initHouseGrid(0, -1);
        scene.initHouseGrid(0, 0);

        scene.initBoundary();

        scene.camera = Camera.init();
        scene.player = player;
        scene.score = 0;
        scene.timeLeft = 60;
        scene.state = .playing;
        scene.houses = scene.reg.view(.{ DropOffLocation, RigidBody }, .{});

        for (0..50) |_| {
            _ = scene.initPedestrian(getRandomPosition());
        }

        _ = scene.initCustomer();
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
        if (scene.reg.len(CustomerComponent) == 0) return;

        _ = scene.initCustomer();

        scene.score += 100;
        rl.playSound(scene.sounds.score);
    }

    fn updatePhysics(scene: *InitialScene, dt: f32) void {
        scene.physicsSystem.update(dt);
        scene.physicsSystem.pollCollisions(*InitialScene, scene, onCollision);
    }

    fn updateCarFriction(scene: *InitialScene, dt: f32) void {
        const body = scene.reg.get(RigidBody, scene.player);

        if (!isOnRoad(body)) {
            const d = body.d.cloneVel().scale(0.9 * 2);

            body.d.v.x.* -= d.x * dt;
            body.d.v.y.* -= d.y * dt;
        }
    }

    fn isOnRoad(body: *RigidBody) bool {
        const isInBlockTL = !isInBlockNonRoad(body.aabb, zlm.vec2(-1, -1));
        const isInBlockTR = !isInBlockNonRoad(body.aabb, zlm.vec2(-1, 0));
        const isInBlockBL = !isInBlockNonRoad(body.aabb, zlm.vec2(0, -1));
        const isInBlockBR = !isInBlockNonRoad(body.aabb, zlm.vec2(0, 0));

        return isInBlockTL or isInBlockTR or isInBlockBL or isInBlockBR;
    }

    fn isInBlockNonRoad(checkAabb: zge.physics.shape.AABB, blockGridPosition: zlm.Vec2) bool {
        const blockSquareRect = getBlockSquareRect(blockGridPosition);

        return checkAabb.intersects(blockSquareRect);
    }

    inline fn getBlockSquareRect(blockGridPosition: zlm.Vec2) zge.physics.shape.AABB {
        const blockSize = blockCellGridSize * 2;
        const gridPositionOffset = blockGridPosition.scale(-2);

        const blockMin = blockGridPosition.scale(blockSize).add(gridPositionOffset);
        const offset = blockMin.scale(0.5 * blockCellSize);
        const margin = 8;

        const tl = offset.add(zlm.Vec2.all(blockCellSize * 0.75 + margin));

        return zge.physics.shape.AABB{
            .tl = tl,
            .br = tl.add(zlm.Vec2.all(blockCellSize * 5 - margin * 2)),
            .isMinimal = true,
        };
    }

    fn updateAnimationAndSound(scene: *InitialScene, t: f64) void {
        const texture = scene.reg.get(TextureComponent, scene.player);
        const body = scene.reg.get(RigidBody, scene.player);

        const v = body.d.cloneVel().abs();
        const a = body.d.cloneAccel().abs();
        const proportionalVelocity = (v.x + v.y) / 200;

        const playerAnimSpeed = 1000 / (v.x * v.x + v.x * 100 + v.y * v.y + v.y * 100);
        const shouldPlayHardTurnSound = (a.x > 0 and v.y > 75) or (a.y > 0 and v.x > 75);
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
        scene.camera.position = body.d.clonePos().neg();
    }

    pub fn handleInput(scene: *InitialScene, dt: f32) void {
        if (scene.state == .gameOver) {
            if (rl.isKeyDown(scene.keybinds.restart)) {
                scene.restart();
            }
            return;
        }

        var a = zlm.Vec2.zero;

        const body = scene.reg.get(RigidBody, scene.player);

        if (rl.isKeyDown(scene.keybinds.left)) {
            a.x = -playerSpeed;
            scene.playerAnim1 = &scene.textures.playerLeft1;
            scene.playerAnim2 = &scene.textures.playerLeft2;
        } else if (rl.isKeyDown(scene.keybinds.right)) {
            a.x = playerSpeed;
            scene.playerAnim1 = &scene.textures.playerRight1;
            scene.playerAnim2 = &scene.textures.playerRight2;
        } else if (rl.isKeyDown(scene.keybinds.up)) {
            a.y = -playerSpeed;
            scene.playerAnim1 = &scene.textures.playerUp1;
            scene.playerAnim2 = &scene.textures.playerUp2;
        } else if (rl.isKeyDown(scene.keybinds.down)) {
            a.y = playerSpeed;
            scene.playerAnim1 = &scene.textures.playerDown1;
            scene.playerAnim2 = &scene.textures.playerDown2;
        }

        if (rl.isKeyDown(scene.keybinds.brake)) {
            a = body.d.cloneVel().neg();
            scene.isBraking = true;
        } else {
            scene.isBraking = false;
        }

        if (rl.isKeyDown(scene.keybinds.honk) and !rl.isSoundPlaying(scene.sounds.horn)) {
            rl.playSound(scene.sounds.horn);
        }

        body.d.setAccel(a);

        // Turning physics, makes car "lock in" when making a turn
        const cv = zlm.vec2(
            if (a.y != 0) -body.d.v.x.* * 0.01 * dt * 200 else 0,
            if (a.x != 0) -body.d.v.y.* * 0.01 * dt * 200 else 0,
        );

        body.d.setVel(body.d.cloneVel().add(cv));
    }

    const BlockConnections = struct {
        left: bool = false,
        top: bool = false,
        right: bool = false,
        bottom: bool = false,
    };

    fn drawBlock(scene: *const InitialScene, blockGridPosition: zlm.Vec2, connections: BlockConnections) void {
        const blockSize = blockCellGridSize * 2;
        const gridPositionOffset = blockGridPosition.scale(-2);

        const blockMin = blockGridPosition.scale(blockSize).add(gridPositionOffset);
        const blockMax = blockMin.add(zlm.Vec2.all(blockSize - 2));
        const edgeRoadsLength = 10;

        // Parks
        const pixelOffset = blockMin.scale(0.5 * blockCellSize).add(zlm.Vec2.all(blockCellSize / 4));
        const park1Position = pixelOffset.add(zlm.Vec2.all(blockCellSize).mul(zlm.vec2(3, 2)));
        const park2Position = pixelOffset.add(zlm.Vec2.all(blockCellSize).mul(zlm.vec2(3, 4)));
        scene.drawSystem.drawTexture(&scene.textures.park, park1Position, 0, scale * 2, scene.camera);
        scene.drawSystem.drawTexture(&scene.textures.park, park2Position, 0, scale * 2, scene.camera);

        // Top Road
        scene.drawRoad(blockMin.add(zlm.vec2(2, 0)), Direction.Right, edgeRoadsLength, scene.camera);
        // Bottom Road
        scene.drawRoad(blockMax.add(zlm.vec2(-1, 0)), Direction.Left, edgeRoadsLength, scene.camera);
        // Left Road
        scene.drawRoad(blockMin.add(zlm.vec2(0, 2)), Direction.Down, edgeRoadsLength, scene.camera);
        // Right Road
        scene.drawRoad(blockMax.add(zlm.vec2(0, -1)), Direction.Up, edgeRoadsLength, scene.camera);

        // Top Left
        if (connections.left and !connections.top) {
            scene.drawTIntersectionHorizontalDown(blockMin, scene.camera);
        } else if (!connections.left and connections.top) {
            scene.drawTIntersectionVerticalRight(blockMin, scene.camera);
        } else if (connections.left and connections.top) {
            scene.drawIntersection(blockMin, scene.camera);
        } else {
            scene.drawTurnFromDownToRight(blockMin, scene.camera);
        }

        // Top Right
        const trp = zlm.vec2(blockMax.x, blockMin.y);
        if (connections.right and !connections.top) {
            scene.drawTIntersectionHorizontalDown(trp, scene.camera);
        } else if (!connections.right and connections.top) {
            scene.drawTIntersectionVerticalLeft(trp, scene.camera);
        } else if (connections.right and connections.top) {
            scene.drawIntersection(trp, scene.camera);
        } else {
            scene.drawTurnFromLeftToDown(trp, scene.camera);
        }

        // Bottom Left
        const blp = zlm.vec2(blockMin.x, blockMax.y);
        if (connections.left and !connections.bottom) {
            scene.drawTIntersectionHorizontalUp(blp, scene.camera);
        } else if (!connections.left and connections.bottom) {
            scene.drawTIntersectionVerticalRight(blp, scene.camera);
        } else if (connections.left and connections.bottom) {
            scene.drawIntersection(blp, scene.camera);
        } else {
            scene.drawTurnFromUpToRight(blp, scene.camera);
        }

        // Bottom Right
        if (connections.right and !connections.bottom) {
            scene.drawTIntersectionHorizontalUp(blockMax, scene.camera);
        } else if (!connections.right and connections.bottom) {
            scene.drawTIntersectionVerticalLeft(blockMax, scene.camera);
        } else if (connections.right and connections.bottom) {
            scene.drawIntersection(blockMax, scene.camera);
        } else {
            scene.drawTurnFromLeftToUp(blockMax, scene.camera);
        }
    }

    const roadSize: f32 = 32;
    pub const Direction = enum { Up, Down, Left, Right };

    pub fn drawRoad(scene: *const InitialScene, p0: zlm.Vec2, direction: Direction, length: usize, camera: Camera) void {
        var pA = p0;
        var pB = p0;
        var d: f32 = 1;
        var textureA: *const rl.Texture2D = undefined;
        var textureB: *const rl.Texture2D = undefined;

        if (direction == Direction.Left or direction == Direction.Right) {
            pB.y += 1;
            textureA = &scene.textures.roadUp;
            textureB = &scene.textures.roadDown;
        } else {
            pB.x += 1;
            textureA = &scene.textures.roadLeft;
            textureB = &scene.textures.roadRight;
        }

        if (direction == Direction.Left or direction == Direction.Up) {
            d = -1;
        }

        for (0..length) |_| {
            const pAs = pA.scale(32 * scale);
            const pBs = pB.scale(32 * scale);

            scene.drawSystem.drawTexture(textureA, pAs, 0, scale, camera);
            scene.drawSystem.drawTexture(textureB, pBs, 0, scale, camera);

            if (direction == Direction.Left or direction == Direction.Right) {
                pA.x += d;
                pB.x += d;
            } else if (direction == Direction.Up or direction == Direction.Down) {
                pA.y += d;
                pB.y += d;
            }
        }
    }

    const RoadConfigurationPositions = struct {
        tl: zlm.Vec2,
        tr: zlm.Vec2,
        bl: zlm.Vec2,
        br: zlm.Vec2,
    };

    fn getRoadConfigurationPositions(position: zlm.Vec2) RoadConfigurationPositions {
        const step = 32 * scale;

        const tl = position.scale(step);
        const tr = tl.add(zlm.vec2(step, 0));
        const bl = position.add(zlm.vec2(0, 1)).scale(step);
        const br = bl.add(zlm.vec2(step, 0));

        return .{ .tl = tl, .tr = tr, .bl = bl, .br = br };
    }

    pub fn drawIntersection(scene: *const InitialScene, position: zlm.Vec2, camera: Camera) void {
        const positions = getRoadConfigurationPositions(position);

        scene.drawSystem.drawTexture(&scene.textures.roadIntersectionTopLeft, positions.tl, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadIntersectionTopRight, positions.tr, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadIntersectionBottomLeft, positions.bl, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadIntersectionBottomRight, positions.br, 0, scale, camera);
    }

    pub fn drawTurnFromDownToRight(scene: *const InitialScene, position: zlm.Vec2, camera: Camera) void {
        const positions = getRoadConfigurationPositions(position);

        scene.drawSystem.drawTexture(&scene.textures.roadCornerTopLeft, positions.tl, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadUp, positions.tr, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadLeft, positions.bl, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadIntersectionBottomRight, positions.br, 0, scale, camera);
    }

    pub fn drawTurnFromUpToRight(scene: *const InitialScene, position: zlm.Vec2, camera: Camera) void {
        const positions = getRoadConfigurationPositions(position);

        scene.drawSystem.drawTexture(&scene.textures.roadLeft, positions.tl, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadIntersectionTopRight, positions.tr, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadCornerBottomLeft, positions.bl, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadDown, positions.br, 0, scale, camera);
    }

    pub fn drawTurnFromLeftToUp(scene: *const InitialScene, position: zlm.Vec2, camera: Camera) void {
        const positions = getRoadConfigurationPositions(position);

        scene.drawSystem.drawTexture(&scene.textures.roadIntersectionTopLeft, positions.tl, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadRight, positions.tr, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadDown, positions.bl, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadCornerBottomRight, positions.br, 0, scale, camera);
    }

    pub fn drawTurnFromLeftToDown(scene: *const InitialScene, position: zlm.Vec2, camera: Camera) void {
        const positions = getRoadConfigurationPositions(position);

        scene.drawSystem.drawTexture(&scene.textures.roadUp, positions.tl, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadCornerTopRight, positions.tr, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadIntersectionBottomLeft, positions.bl, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadRight, positions.br, 0, scale, camera);
    }

    pub fn drawTIntersectionHorizontalUp(scene: *const InitialScene, position: zlm.Vec2, camera: Camera) void {
        const positions = getRoadConfigurationPositions(position);

        scene.drawSystem.drawTexture(&scene.textures.roadIntersectionTopLeft, positions.tl, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadIntersectionTopRight, positions.tr, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadDown, positions.bl, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadDown, positions.br, 0, scale, camera);
    }

    pub fn drawTIntersectionHorizontalDown(scene: *const InitialScene, position: zlm.Vec2, camera: Camera) void {
        const positions = getRoadConfigurationPositions(position);

        scene.drawSystem.drawTexture(&scene.textures.roadUp, positions.tl, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadUp, positions.tr, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadIntersectionBottomLeft, positions.bl, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadIntersectionBottomRight, positions.br, 0, scale, camera);
    }

    pub fn drawTIntersectionVerticalLeft(scene: *const InitialScene, position: zlm.Vec2, camera: Camera) void {
        const positions = getRoadConfigurationPositions(position);

        scene.drawSystem.drawTexture(&scene.textures.roadIntersectionTopLeft, positions.tl, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadRight, positions.tr, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadIntersectionBottomLeft, positions.bl, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadRight, positions.br, 0, scale, camera);
    }

    pub fn drawTIntersectionVerticalRight(scene: *const InitialScene, position: zlm.Vec2, camera: Camera) void {
        const positions = getRoadConfigurationPositions(position);

        scene.drawSystem.drawTexture(&scene.textures.roadLeft, positions.tl, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadIntersectionTopRight, positions.tr, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadLeft, positions.bl, 0, scale, camera);
        scene.drawSystem.drawTexture(&scene.textures.roadIntersectionBottomRight, positions.br, 0, scale, camera);
    }

    fn drawTopFences(scene: *const InitialScene) void {
        const xStep: f32 = @as(f32, @floatFromInt(scene.textures.fenceY.width)) * scale;

        const xSteps = @as(usize, @intFromFloat(@divFloor((boundaries.r - boundaries.l), xStep)));

        // Top
        for (1..xSteps) |i| {
            const if32 = @as(f32, @floatFromInt(i));
            const p = zlm.vec2(boundaries.l + if32 * xStep, boundaries.t);
            scene.drawSystem.drawTexture(&scene.textures.fenceY, p, 0, scale, scene.camera);
        }

        // Top Left
        scene.drawSystem.drawTexture(&scene.textures.fenceTopLeft, zlm.vec2(boundaries.l, boundaries.t), 0, scale, scene.camera);
        // Top Right
        scene.drawSystem.drawTexture(&scene.textures.fenceTopRight, zlm.vec2(boundaries.r, boundaries.t), 0, scale, scene.camera);
    }

    fn drawBottomAndSideFences(scene: *const InitialScene) void {
        const xStep: f32 = @as(f32, @floatFromInt(scene.textures.fenceY.width)) * scale;
        const yStep: f32 = @as(f32, @floatFromInt(scene.textures.fenceX.height)) * scale;

        const xSteps = @as(usize, @intFromFloat(@divFloor((boundaries.r - boundaries.l), xStep)));
        const ySteps = @as(usize, @intFromFloat(@divFloor((boundaries.b - boundaries.t), yStep)));

        // Bottom
        for (1..xSteps) |i| {
            const if32 = @as(f32, @floatFromInt(i));
            const x = boundaries.l + if32 * xStep;
            const y = boundaries.b;
            scene.drawSystem.drawTexture(&scene.textures.fenceY, zlm.vec2(x, y), 0, scale, scene.camera);
        }

        // Left and Right
        for (1..ySteps) |i| {
            const if32 = @as(f32, @floatFromInt(i));

            const xl = boundaries.l;
            const yl = boundaries.t + if32 * yStep;
            scene.drawSystem.drawTexture(&scene.textures.fenceX, zlm.vec2(xl, yl), 0, scale, scene.camera);

            const xr = boundaries.r;
            const yr = boundaries.t + if32 * yStep;
            scene.drawSystem.drawTexture(&scene.textures.fenceX, zlm.vec2(xr, yr), 0, scale, scene.camera);
        }

        // Bottom Left
        scene.drawSystem.drawTexture(&scene.textures.fenceBottomLeft, zlm.vec2(boundaries.l, boundaries.b), 0, scale, scene.camera);
        // Bottom Right
        scene.drawSystem.drawTexture(&scene.textures.fenceBottomRight, zlm.vec2(boundaries.r, boundaries.b), 0, scale, scene.camera);
    }

    pub fn draw(s: *anyopaque, _: f32, _: f64) void {
        var scene: *InitialScene = @ptrCast(@alignCast(s));

        rl.beginDrawing();

        rl.clearBackground(rl.Color.init(0x82, 0x82, 0x82, 0xff));

        scene.drawBlock(zlm.vec2(-1, -1), .{ .right = true, .bottom = true });
        scene.drawBlock(zlm.vec2(0, -1), .{ .left = true, .bottom = true });
        scene.drawBlock(zlm.vec2(-1, 0), .{ .right = true, .top = true });
        scene.drawBlock(zlm.vec2(0, 0), .{ .left = true, .top = true });

        scene.drawTopFences();

        scene.drawDropOffLocation();

        scene.drawSystem.draw(scene.camera);

        scene.drawBottomAndSideFences();

        //scene.drawDebugBlockSquare();

        scene.drawTargetArrow();

        scene.drawScore();
        scene.drawTimeLeft();
        if (scene.state == .gameOver) scene.drawGameOver();

        rl.drawFPS(5, 128);

        rl.endDrawing();
    }

    fn drawTextCenter(font: rl.Font, text: [*:0]const u8, position: zlm.Vec2, fontSize: f32, spacing: f32, tint: rl.Color) void {
        const textSize = rl.measureTextEx(font, text, fontSize, spacing);
        const pos = zge.vector.r2z(textSize).scale(-2).add(position);
        rl.drawTextEx(font, text, zge.vector.z2r(pos), fontSize, spacing, tint);
    }

    fn drawGameOver(scene: *const InitialScene) void {
        const gameOverPos = scene.screen.size.div(zlm.vec2(2, 3));
        const instructionsPos = zlm.vec2(scene.screen.sizeHalf.x, gameOverPos.y + 128);

        drawTextCenter(rl.getFontDefault(), "Game Over", gameOverPos, 96, 8, rl.Color.white);
        drawTextCenter(rl.getFontDefault(), "Press SPACE to restart", instructionsPos, 32, 2, rl.Color.white);

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
                rl.getFontDefault(),
                placementText,
                scene.screen.sizeHalf.add(zlm.vec2(0, 128)),
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

            const p = scene.screen.sizeHalf.add(zlm.vec2(
                0,
                128 + 96 + @as(f32, @floatFromInt(i)) * 36,
            ));
            drawTextCenter(rl.getFontDefault(), &highscoreBuffer, p, 32, 2, highscoreColors[i]);
        }
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

    fn drawTimeLeft(scene: *const InitialScene) void {
        var buffer: [8:0]u8 = undefined;
        const slice = std.fmt.bufPrint(&buffer, "{d:.2}s", .{scene.timeLeft}) catch |err| {
            std.log.err("Error printing: {}", .{err});
            return;
        };
        buffer[slice.len] = 0;

        const color = if (scene.timeLeft == 0) rl.Color.red else rl.Color.white;

        rl.drawTextEx(rl.getFontDefault(), &buffer, rl.Vector2.init((scene.screen.size.x - 96) / 2, 5), 48, 2, color);
    }

    fn drawDropOffLocation(scene: *InitialScene) void {
        const view = scene.reg.basicView(CustomerComponent);

        for (view.raw()) |customer| {
            switch (customer.state) {
                .transportingToDropOff => |dropOff| {
                    const size = zlm.vec2(72, 48);
                    const p = scene.screen.screenPositionV(scene.camera.transformV(
                        dropOff.destination.sub(size.scale(0.5)),
                    ));
                    rl.drawRectangleV(zge.vector.z2r(p), zge.vector.z2r(size), rl.Color.green);
                },
                else => continue,
            }
        }
    }

    fn drawPhysicalRects(scene: *const InitialScene) void {
        const view = scene.reg.basicView(RigidBody);

        for (view.raw()) |body| {
            const p = scene.screen.screenPositionV(scene.camera.v(body.aabb.tl));

            rl.drawRectangleV(rl.Vector2.init(p.x - 2, p.y - 2), rl.Vector2.init(4, 4), rl.Color.red);

            rl.drawRectangleV(
                zge.vector.z2r(p),
                zge.vector.z2r(
                    body.aabb.size().scale(scene.camera.s),
                ),
                rl.Color.white,
            );
        }
    }

    fn drawDebugBlockSquare(scene: *const InitialScene) void {
        const squares: []const zge.physics.shape.AABB = &.{
            getBlockSquareRect(zlm.vec2(-1, -1)),
            getBlockSquareRect(zlm.vec2(-1, 0)),
            getBlockSquareRect(zlm.vec2(0, -1)),
            getBlockSquareRect(zlm.vec2(0, 0)),
        };

        for (squares) |square| {
            const p = scene.screen.screenPositionV(scene.camera.transformV(square.tl));

            rl.drawRectangleV(zge.vector.z2r(p), rl.Vector2.init(square.width(), square.height()), rl.Color.white);
        }
    }

    fn drawTargetArrow(scene: *InitialScene) void {
        const target = scene.getTargetPosition() orelse return;
        const body = scene.reg.getConst(RigidBody, scene.player);
        //const source = rl.Vector2.init(scene.camera.rect.x, scene.camera.rect.y);
        const source = body.d.clonePos();

        const screenEdgePosition = scene.getTargetScreenEdgePosition(target, source) orelse return;
        const arrowPosition = scene.screen.screenPositionV(scene.camera.transformV(screenEdgePosition));

        const d = target.sub(source);
        const r = std.math.radiansToDegrees(std.math.atan2(d.y, d.x));

        const sourceT = rl.Rectangle.init(
            0,
            0,
            @as(f32, @floatFromInt(scene.textures.targetArrow.width)),
            @as(f32, @floatFromInt(scene.textures.targetArrow.height)),
        );
        const dest = rl.Rectangle.init(arrowPosition.x, arrowPosition.y, 64, 64);
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

    fn getTargetScreenEdgePosition(scene: *const InitialScene, target: zlm.Vec2, source: zlm.Vec2) ?zlm.Vec2 {
        const sizeHalf = scene.camera.size.sub(zlm.Vec2.all(128)).scale(0.5);
        const tl = zge.vector.z2r(source.sub(sizeHalf));
        const br = zge.vector.z2r(source.add(sizeHalf));
        const tr = rl.Vector2.init(br.x, tl.y);
        const bl = rl.Vector2.init(tl.x, br.y);

        var collisionPoint: rl.Vector2 = undefined;

        const src = zge.vector.z2r(source);
        const tgt = zge.vector.z2r(target);

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

        return zge.vector.r2z(collisionPoint);
    }

    fn getTargetPosition(scene: *InitialScene) ?zlm.Vec2 {
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
