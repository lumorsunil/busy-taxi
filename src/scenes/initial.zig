const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const rl = @import("raylib");

const EntityError = @import("../state.zig").EntityError;
const ComponentError = @import("../state.zig").ComponentError;

const stateConfig = @import("../state-config.zig").stateConfig;
const GameState = @import("../state-config.zig").GameState;
const stateTextures = @import("../state-config.zig").stateTextures;

const Keybinds = @import("../input.zig").Keybinds;

const Transform = @import("../components.zig").Transform;
const Physics = @import("../components.zig").Physics;
const AnimationComponent = @import("../components.zig").AnimationComponent;
const RandomWalk = @import("../components.zig").RandomWalk;
const Label = @import("../components.zig").Label;

const DrawSystem = @import("../systems/draw.zig").DrawSystem;
const PhysicsSystem = @import("../systems/physics.zig").PhysicsSystem;
const AnimationSystem = @import("../systems/animation.zig").AnimationSystem;
const RandomWalkSystem = @import("../systems/random-walk.zig").RandomWalkSystem;
const CustomerSystem = @import("../systems/customer.zig").CustomerSystem;

const CollisionEvent = @import("../systems/physics.zig").CollisionEvent;

const road = @import("../road.zig");

const animations = @import("../animations.zig");
const animation = @import("../animation.zig");
const Animation = animation.Animation;
const AnimationInstance = animation.AnimationInstance;

const Camera = @import("../camera.zig").Camera;
const screen = @import("../screen.zig");

const cfg = @import("../config.zig");
const size = cfg.size;

const playerSpeed = 300;

const scale = 2;

const blockCellSize = 64 * scale;
const blockCellGridSize = 7;

const boundaryPadding = 64;
const boundaries = .{
    .l = -boundaryPadding - (blockCellGridSize - 1) * blockCellSize,
    .r = cfg.size.w + boundaryPadding - blockCellSize / 2,
    .t = -boundaryPadding - (blockCellGridSize - 1) * blockCellSize,
    .b = cfg.size.h + boundaryPadding - blockCellSize / 2,
};

var rand = std.Random.DefaultPrng.init(1);

inline fn getRandomPosition() rl.Vector2 {
    const x = rand.random().float(f32) * (boundaries.r - boundaries.l) + boundaries.l;
    const y = rand.random().float(f32) * (boundaries.b - boundaries.t) + boundaries.t;

    return rl.Vector2.init(x, y);
}

pub const InitialScene = struct {
    camera: Camera,
    player: usize,
    playerAnim1: *const rl.Texture2D,
    playerAnim2: *const rl.Texture2D,
    playerAnimLast: f64 = 0,
    engineSoundLast: f64 = 0,
    hardTurnSoundLast: f64 = 0,
    isBraking: bool = false,

    houses: ArrayList(usize),

    keybinds: Keybinds = .{
        .up = rl.KeyboardKey.key_w,
        .down = rl.KeyboardKey.key_s,
        .left = rl.KeyboardKey.key_a,
        .right = rl.KeyboardKey.key_d,
        .brake = rl.KeyboardKey.key_space,
        .honk = rl.KeyboardKey.key_g,
    },

    animationPedestrianBlueWalk: *Animation,
    animationPedestrianRedWalk: *Animation,

    drawSystem: DrawSystem,
    physicsSystem: PhysicsSystem,
    animationSystem: AnimationSystem,

    allocator: Allocator,

    pub fn init(allocator: Allocator, state: *GameState) !InitialScene {
        const textures = stateTextures(state);

        const player = try initPlayer(state);

        try initHouseGrid(state, -1, -1);
        try initHouseGrid(state, -1, 0);
        try initHouseGrid(state, 0, -1);
        try initHouseGrid(state, 0, 0);

        try initBoundary(state);

        var scene = InitialScene{
            .camera = Camera.init(),

            .player = player,
            .playerAnim1 = &textures.playerLeft1,
            .playerAnim2 = &textures.playerLeft2,

            .houses = ArrayList(usize).init(allocator),

            .animationPedestrianBlueWalk = try allocator.create(Animation),
            .animationPedestrianRedWalk = try allocator.create(Animation),

            .drawSystem = DrawSystem{},
            .physicsSystem = PhysicsSystem{},
            .animationSystem = AnimationSystem{},

            .allocator = allocator,
        };

        for (0..state.entities.len) |entity| {
            const label = state.getComponent(Label, entity) catch continue;

            if (!std.mem.eql(u8, label.label, "House")) continue;

            try scene.houses.append(entity);
        }

        scene.animationPedestrianBlueWalk.* = try animations.pedestrianBlueWalkAnimation(allocator, textures);
        scene.animationPedestrianRedWalk.* = try animations.pedestrianRedWalkAnimation(allocator, textures);

        for (0..50) |_| {
            _ = try scene.initPedestrian(state, getRandomPosition());
        }

        _ = try scene.initCustomer(state);

        scene.drawSystem.printDebug(state);

        return scene;
    }

    pub fn deinit(scene: *InitialScene) void {
        scene.animationPedestrianBlueWalk.deinit(scene.allocator);
        scene.animationPedestrianRedWalk.deinit(scene.allocator);
        scene.allocator.destroy(scene.animationPedestrianBlueWalk);
        scene.allocator.destroy(scene.animationPedestrianRedWalk);
        scene.houses.deinit();
    }

    pub fn initPlayer(state: *GameState) (EntityError || ComponentError)!usize {
        const textures = stateTextures(state);

        const player = try state.addEntity();

        state.setComponent(Label, player, .{ .label = "Player" });

        state.setComponent(Transform, player, Transform{
            .p = rl.Vector2.init(
                (-blockCellGridSize + 1) * blockCellSize,
                (-blockCellGridSize + 1) * blockCellSize,
            ),
            .s = scale,
        });

        state.setComponent(Physics, player, Physics{
            .cr = rl.Rectangle.init(1, 4, 30, 22),
            .isSolid = true,
        });
        state.setComponent(*const rl.Texture2D, player, &textures.playerLeft1);

        return player;
    }

    fn initHouseGrid(state: *GameState, x: f32, y: f32) !void {
        const textures = stateTextures(state);

        const ox = x * blockCellGridSize - x;
        const oy = y * blockCellGridSize - y;

        _ = try initHouse(state, 1 + ox, 1 + oy, &textures.houseGreen);
        _ = try initHouse(state, 3 + ox, 1 + oy, &textures.houseBlue);
        _ = try initHouse(state, 5 + ox, 1 + oy, &textures.houseBlue);

        _ = try initHouse(state, 1 + ox, 3 + oy, &textures.houseOrange);
        _ = try initHouse(state, 3 + ox, 3 + oy, &textures.houseRed);
        _ = try initHouse(state, 5 + ox, 3 + oy, &textures.houseGreen);

        _ = try initHouse(state, 1 + ox, 5 + oy, &textures.houseRed);
        _ = try initHouse(state, 3 + ox, 5 + oy, &textures.houseBlue);
        _ = try initHouse(state, 5 + ox, 5 + oy, &textures.houseOrange);
    }

    pub fn initHouse(state: *GameState, x: f32, y: f32, texture: *const rl.Texture2D) (EntityError || ComponentError)!usize {
        const textures = stateTextures(state);

        const house = try state.addEntity();

        state.setComponent(Label, house, .{ .label = "House" });

        state.setComponent(Transform, house, Transform{
            .p = rl.Vector2.init(128 * x, 128 * y),
            .s = scale * 2,
        });

        const l: f32 = if (texture == &textures.houseOrange) 10 else 4;
        const w: f32 = if (texture == &textures.houseOrange) 12 else 24;
        const t: f32 = 10;
        const h: f32 = 12;

        state.setComponent(Physics, house, Physics{
            .cr = rl.Rectangle.init(l, t, w, h),
            .isSolid = true,
            .isStatic = true,
        });
        state.setComponent(*const rl.Texture2D, house, texture);

        return house;
    }

    pub fn initBoundary(state: *GameState) !void {
        const boundaryLeft = try state.addEntity();
        const boundaryRight = try state.addEntity();
        const boundaryTop = try state.addEntity();
        const boundaryBottom = try state.addEntity();

        const xh = (boundaries.b - boundaries.t) / scale;

        const l = boundaries.l;
        const t = boundaries.t;
        const r = boundaries.r;
        const b = boundaries.b;

        const a = blockCellSize / 4;

        state.setComponent(Transform, boundaryLeft, Transform{
            .p = rl.Vector2.init(l, t + a),
            .s = scale,
        });

        state.setComponent(Physics, boundaryLeft, Physics{
            .cr = rl.Rectangle.init(14, 0, 2, xh),
            .isSolid = true,
            .isStatic = true,
        });

        state.setComponent(Transform, boundaryRight, Transform{
            .p = rl.Vector2.init(r, t + a),
            .s = scale,
        });

        state.setComponent(Physics, boundaryRight, Physics{
            .cr = rl.Rectangle.init(14, 0, 2, xh),
            .isSolid = true,
            .isStatic = true,
        });

        const yw = (boundaries.r - boundaries.l) / scale;

        state.setComponent(Transform, boundaryTop, Transform{
            .p = rl.Vector2.init(l + a, t),
            .s = scale,
        });

        state.setComponent(Physics, boundaryTop, Physics{
            .cr = rl.Rectangle.init(0, 13, yw, 6),
            .isSolid = true,
            .isStatic = true,
        });

        state.setComponent(Transform, boundaryBottom, Transform{
            .p = rl.Vector2.init(l + a, b),
            .s = scale,
        });

        state.setComponent(Physics, boundaryBottom, Physics{
            .cr = rl.Rectangle.init(0, 13, yw, 6),
            .isSolid = true,
            .isStatic = true,
        });
    }

    fn initPedestrian(scene: *const InitialScene, state: *GameState, position: rl.Vector2) !usize {
        const pedestrian = try state.addEntity();

        state.setComponent(Label, pedestrian, .{ .label = "Pedestrian" });

        state.setComponent(Transform, pedestrian, Transform{
            .p = position,
            .s = scale,
        });

        state.setComponent(Physics, pedestrian, Physics{
            .cr = rl.Rectangle.init(2, 6, 9, 7),
            .f = 1,
            .isSolid = true,
        });

        const animationInstance = AnimationInstance.init(scene.animationPedestrianBlueWalk);
        state.setComponent(AnimationComponent, pedestrian, AnimationComponent{ .animationInstance = animationInstance });

        state.setComponent(*const rl.Texture2D, pedestrian, animationInstance.getCurrentTexture());

        state.setComponent(RandomWalk, pedestrian, RandomWalk.init());

        return pedestrian;
    }

    fn initCustomer(scene: *InitialScene, state: *GameState) !usize {
        const customer = try state.addEntity();

        state.setComponent(Label, customer, .{ .label = "Customer" });

        var p = scene.getRandomDropOffLocation(state).p;
        p.x += 64;
        p.y += 96;
        state.setComponent(Transform, customer, Transform{
            .p = p,
            .s = scale,
        });

        state.setComponent(Physics, customer, Physics{
            .cr = rl.Rectangle.init(2, 6, 9, 7),
            .f = 1,
        });

        var animationInstance = AnimationInstance.init(scene.animationPedestrianRedWalk);
        animationInstance.pause();
        state.setComponent(AnimationComponent, customer, AnimationComponent{ .animationInstance = animationInstance });

        state.setComponent(*const rl.Texture2D, customer, animationInstance.getCurrentTexture());

        return customer;
    }

    fn getRandomDropOffLocation(scene: *InitialScene, state: *GameState) *Transform {
        const i = rand.random().intRangeLessThan(usize, 0, scene.houses.items.len);
        const house = scene.houses.items[i];
        return state.getComponent(Transform, house) catch unreachable;
    }

    const EventHandlerContext = struct { scene: *InitialScene, state: *GameState };

    fn onCollision(context: *EventHandlerContext, event: CollisionEvent) void {
        if (event.entityA == context.scene.player or event.entityB == context.scene.player and !rl.isSoundPlaying(context.state.sounds.crash)) {
            rl.playSound(context.state.sounds.crash);
        }
    }

    pub fn update(scene: *InitialScene, state: *GameState, dt: f32, t: f64) !void {
        const transform = try state.getComponent(Transform, scene.player);
        const physics = try state.getComponent(Physics, scene.player);

        try scene.handleInput(state, dt);
        scene.updatePhysics(state, dt);
        try scene.updateCarFriction(state, dt);
        try scene.updateAnimationAndSound(state, transform, physics, t);
        RandomWalkSystem.update(state, t);
        CustomerSystem.update(state, scene.player);
        scene.updateCamera(transform);
    }

    fn updatePhysics(scene: *InitialScene, state: *GameState, dt: f32) void {
        scene.physicsSystem.update(state, dt);
        var eventHandlerContext = EventHandlerContext{ .scene = scene, .state = state };
        scene.physicsSystem.pollCollisions(EventHandlerContext, &eventHandlerContext, onCollision);
    }

    fn updateCarFriction(scene: *InitialScene, state: *GameState, dt: f32) !void {
        const transform = try state.getComponent(Transform, scene.player);
        const physics = try state.getComponent(Physics, scene.player);

        if (!isOnRoad(transform, physics)) {
            const dx = physics.v.x * 0.9 * 2;
            const dy = physics.v.y * 0.9 * 2;

            physics.v.x -= dx * dt;
            physics.v.y -= dy * dt;
        }
    }

    fn isOnRoad(transform: *const Transform, physics: *const Physics) bool {
        const playerRect = PhysicsSystem.getPhysicalRect(physics, transform);

        return !(isInBlockNonRoad(playerRect, rl.Vector2.init(-1, -1)) or isInBlockNonRoad(playerRect, rl.Vector2.init(-1, 0)) or isInBlockNonRoad(playerRect, rl.Vector2.init(0, -1)) or isInBlockNonRoad(playerRect, rl.Vector2.init(0, 0)));
    }

    fn isInBlockNonRoad(rect: rl.Rectangle, blockGridPosition: rl.Vector2) bool {
        const blockSquareRect = getBlockSquareRect(blockGridPosition);

        return rect.checkCollision(blockSquareRect);
    }

    inline fn getBlockSquareRect(blockGridPosition: rl.Vector2) rl.Rectangle {
        const blockSize = blockCellGridSize * 2;
        const gridPositionOffsetX = -blockGridPosition.x * 2;
        const gridPositionOffsetY = -blockGridPosition.y * 2;

        const blockLeft = blockGridPosition.x * blockSize + gridPositionOffsetX;
        const blockTop = blockGridPosition.y * blockSize + gridPositionOffsetY;

        const offsetX = blockLeft / 2 * blockCellSize;
        const offsetY = blockTop / 2 * blockCellSize;

        const adjustX = 8;

        return rl.Rectangle.init(offsetX + blockCellSize + adjustX, offsetY + blockCellSize, blockCellSize * 5 - adjustX * 2, blockCellSize * 5);
    }

    fn updateAnimationAndSound(scene: *InitialScene, state: *GameState, _: *Transform, physics: *Physics, t: f64) !void {
        const texture = try state.getComponent(*const rl.Texture2D, scene.player);

        const vx = @abs(physics.v.x);
        const vy = @abs(physics.v.y);
        const ax = @abs(physics.a.x);
        const ay = @abs(physics.a.y);
        const proportionalVelocity = (vx + vy) / 200;

        const playerAnimSpeed = 1000 / (vx * vx + vx * 100 + vy * vy + vy * 100);
        const shouldPlayHardTurnSound = (ax > 0 and vy > 75) or (ay > 0 and vx > 75);
        const engineSoundScale = @min(@max(proportionalVelocity + 0.5, 0.75), 3);

        if (scene.playerAnimLast < t - playerAnimSpeed) {
            if (texture.* == scene.playerAnim1) {
                texture.* = scene.playerAnim2;
            } else {
                texture.* = scene.playerAnim1;
            }
            scene.playerAnimLast = t;

            if (scene.engineSoundLast < t - 0.43 / engineSoundScale) {
                rl.playSound(state.sounds.engine);
                scene.engineSoundLast = t;
            }

            rl.setSoundPitch(state.sounds.engine, engineSoundScale);
        }

        if (shouldPlayHardTurnSound and scene.hardTurnSoundLast < t - 0.2) {
            rl.playSound(state.sounds.hardTurn);
            scene.hardTurnSoundLast = t;
        }

        scene.animationSystem.update(state, t);
    }

    fn updateCamera(scene: *InitialScene, playerTransform: *Transform) void {
        scene.camera.rect.x = -playerTransform.p.x;
        scene.camera.rect.y = -playerTransform.p.y;
    }

    pub fn handleInput(scene: *InitialScene, state: *GameState, dt: f32) !void {
        const textures = stateTextures(state);

        var ax: f32 = 0;
        var ay: f32 = 0;

        const physics = try state.getComponent(Physics, scene.player);

        if (rl.isKeyDown(scene.keybinds.left)) {
            ax = -playerSpeed;
            scene.playerAnim1 = &textures.playerLeft1;
            scene.playerAnim2 = &textures.playerLeft2;
        } else if (rl.isKeyDown(scene.keybinds.right)) {
            ax = playerSpeed;
            scene.playerAnim1 = &textures.playerRight1;
            scene.playerAnim2 = &textures.playerRight2;
        } else if (rl.isKeyDown(scene.keybinds.up)) {
            ay = -playerSpeed;
            scene.playerAnim1 = &textures.playerUp1;
            scene.playerAnim2 = &textures.playerUp2;
        } else if (rl.isKeyDown(scene.keybinds.down)) {
            ay = playerSpeed;
            scene.playerAnim1 = &textures.playerDown1;
            scene.playerAnim2 = &textures.playerDown2;
        }

        if (rl.isKeyDown(scene.keybinds.brake)) {
            ax = -physics.v.x;
            ay = -physics.v.y;
            scene.isBraking = true;
        } else {
            scene.isBraking = false;
        }

        if (rl.isKeyDown(scene.keybinds.honk) and !rl.isSoundPlaying(state.sounds.horn)) {
            rl.playSound(state.sounds.horn);
        }

        physics.a.x = ax;
        physics.a.y = ay;

        // Turning physics, makes car "lock in" when making a turn
        if (ay != 0) {
            physics.v.x -= physics.v.x * 0.01 * dt * 200;
        }
        if (ax != 0) {
            physics.v.y -= physics.v.y * 0.01 * dt * 200;
        }
    }

    const BlockConnections = struct {
        left: bool = false,
        top: bool = false,
        right: bool = false,
        bottom: bool = false,
    };

    fn drawBlock(scene: *const InitialScene, state: *const GameState, blockGridPosition: rl.Vector2, connections: BlockConnections) void {
        const textures = stateTextures(state);

        const blockSize = blockCellGridSize * 2;
        const gridPositionOffsetX = -blockGridPosition.x * 2;
        const gridPositionOffsetY = -blockGridPosition.y * 2;

        const blockLeft = blockGridPosition.x * blockSize + gridPositionOffsetX;
        const blockTop = blockGridPosition.y * blockSize + gridPositionOffsetY;
        const blockRight = blockSize - 2 + blockLeft;
        const blockBottom = blockSize - 2 + blockTop;
        const edgeRoadsLength = 10;

        const offsetX = blockLeft / 2 * blockCellSize;
        const offsetY = blockTop / 2 * blockCellSize;

        // Parks
        DrawSystem.drawTexture(&textures.park, rl.Vector2.init(3 * blockCellSize + offsetX, 2 * blockCellSize + offsetY), 0, scale * 2, scene.camera);
        DrawSystem.drawTexture(&textures.park, rl.Vector2.init(3 * blockCellSize + offsetX, 4 * blockCellSize + offsetY), 0, scale * 2, scene.camera);

        // Top Road
        road.drawRoad(state, rl.Vector2.init(2 + blockLeft, blockTop), road.Direction.Right, edgeRoadsLength, scale, scene.camera);
        // Bottom Road
        road.drawRoad(state, rl.Vector2.init(2 + blockLeft, blockBottom), road.Direction.Right, edgeRoadsLength, scale, scene.camera);
        // Left Road
        road.drawRoad(state, rl.Vector2.init(blockLeft, 2 + blockTop), road.Direction.Down, edgeRoadsLength, scale, scene.camera);
        // Right Road
        road.drawRoad(state, rl.Vector2.init(blockRight, 2 + blockTop), road.Direction.Down, edgeRoadsLength, scale, scene.camera);

        // Top Left
        const tlp = rl.Vector2.init(blockLeft, blockTop);
        if (connections.left and !connections.top) {
            road.drawTIntersectionHorizontalDown(state, tlp, scale, scene.camera);
        } else if (!connections.left and connections.top) {
            road.drawTIntersectionVerticalRight(state, tlp, scale, scene.camera);
        } else if (connections.left and connections.top) {
            road.drawIntersection(state, tlp, scale, scene.camera);
        } else {
            road.drawTurnFromDownToRight(state, tlp, scale, scene.camera);
        }

        // Top Right
        const trp = rl.Vector2.init(blockRight, blockTop);
        if (connections.right and !connections.top) {
            road.drawTIntersectionHorizontalDown(state, trp, scale, scene.camera);
        } else if (!connections.right and connections.top) {
            road.drawTIntersectionVerticalLeft(state, trp, scale, scene.camera);
        } else if (connections.right and connections.top) {
            road.drawIntersection(state, trp, scale, scene.camera);
        } else {
            road.drawTurnFromLeftToDown(state, trp, scale, scene.camera);
        }

        // Bottom Left
        const blp = rl.Vector2.init(blockLeft, blockBottom);
        if (connections.left and !connections.bottom) {
            road.drawTIntersectionHorizontalUp(state, blp, scale, scene.camera);
        } else if (!connections.left and connections.bottom) {
            road.drawTIntersectionVerticalRight(state, blp, scale, scene.camera);
        } else if (connections.left and connections.bottom) {
            road.drawIntersection(state, blp, scale, scene.camera);
        } else {
            road.drawTurnFromUpToRight(state, blp, scale, scene.camera);
        }

        // Bottom Right
        const brp = rl.Vector2.init(blockRight, blockBottom);
        if (connections.right and !connections.bottom) {
            road.drawTIntersectionHorizontalUp(state, brp, scale, scene.camera);
        } else if (!connections.right and connections.bottom) {
            road.drawTIntersectionVerticalLeft(state, brp, scale, scene.camera);
        } else if (connections.right and connections.bottom) {
            road.drawIntersection(state, brp, scale, scene.camera);
        } else {
            road.drawTurnFromLeftToUp(state, brp, scale, scene.camera);
        }
    }

    fn drawTopFences(scene: *const InitialScene, state: *GameState) void {
        const textures = stateTextures(state);

        const xStep: f32 = @as(f32, @floatFromInt(textures.fenceY.width)) * scale;

        const xSteps = @as(usize, @intFromFloat(@divFloor((boundaries.r - boundaries.l), xStep)));

        // Top
        for (1..xSteps) |i| {
            const if32 = @as(f32, @floatFromInt(i));
            const x = boundaries.l + if32 * xStep;
            const y = boundaries.t;
            DrawSystem.drawTexture(&textures.fenceY, rl.Vector2.init(x, y), 0, scale, scene.camera);
        }

        // Top Left
        DrawSystem.drawTexture(&textures.fenceTopLeft, rl.Vector2.init(boundaries.l, boundaries.t), 0, scale, scene.camera);
        // Top Right
        DrawSystem.drawTexture(&textures.fenceTopRight, rl.Vector2.init(boundaries.r, boundaries.t), 0, scale, scene.camera);
    }

    fn drawBottomAndSideFences(scene: *const InitialScene, state: *GameState) void {
        const textures = stateTextures(state);

        const xStep: f32 = @as(f32, @floatFromInt(textures.fenceY.width)) * scale;
        const yStep: f32 = @as(f32, @floatFromInt(textures.fenceX.height)) * scale;

        const xSteps = @as(usize, @intFromFloat(@divFloor((boundaries.r - boundaries.l), xStep)));
        const ySteps = @as(usize, @intFromFloat(@divFloor((boundaries.b - boundaries.t), yStep)));

        // Bottom
        for (1..xSteps) |i| {
            const if32 = @as(f32, @floatFromInt(i));
            const x = boundaries.l + if32 * xStep;
            const y = boundaries.b;
            DrawSystem.drawTexture(&textures.fenceY, rl.Vector2.init(x, y), 0, scale, scene.camera);
        }

        // Left and Right
        for (1..ySteps) |i| {
            const if32 = @as(f32, @floatFromInt(i));

            const xl = boundaries.l;
            const yl = boundaries.t + if32 * yStep;
            DrawSystem.drawTexture(&textures.fenceX, rl.Vector2.init(xl, yl), 0, scale, scene.camera);

            const xr = boundaries.r;
            const yr = boundaries.t + if32 * yStep;
            DrawSystem.drawTexture(&textures.fenceX, rl.Vector2.init(xr, yr), 0, scale, scene.camera);
        }

        // Bottom Left
        DrawSystem.drawTexture(&textures.fenceBottomLeft, rl.Vector2.init(boundaries.l, boundaries.b), 0, scale, scene.camera);
        // Bottom Right
        DrawSystem.drawTexture(&textures.fenceBottomRight, rl.Vector2.init(boundaries.r, boundaries.b), 0, scale, scene.camera);
    }

    pub fn draw(scene: *const InitialScene, state: *GameState) void {
        rl.beginDrawing();

        rl.clearBackground(rl.Color.init(0x82, 0x82, 0x82, 0xff));

        scene.drawBlock(state, rl.Vector2.init(-1, -1), .{ .right = true, .bottom = true });
        scene.drawBlock(state, rl.Vector2.init(0, -1), .{ .left = true, .bottom = true });
        scene.drawBlock(state, rl.Vector2.init(-1, 0), .{ .right = true, .top = true });
        scene.drawBlock(state, rl.Vector2.init(0, 0), .{ .left = true, .top = true });

        scene.drawTopFences(state);

        scene.drawSystem.draw(state, scene.camera);

        scene.drawBottomAndSideFences(state);

        rl.endDrawing();
    }

    fn drawPhysicalRects(scene: *const InitialScene, state: *const GameState) void {
        for (0..state.entities.len) |entity| {
            const transform = state.getComponent(Transform, entity) catch continue;
            const physics = state.getComponent(Physics, entity) catch continue;

            const p = screen.screenPositionV(scene.camera.v(rl.Vector2.init(
                transform.p.x + physics.cr.x * transform.s,
                transform.p.y + physics.cr.y * transform.s,
            )));

            rl.drawRectangleV(rl.Vector2.init(p.x - 2, p.y - 2), rl.Vector2.init(4, 4), rl.Color.red);

            rl.drawRectangleV(
                p,
                rl.Vector2.init(
                    physics.cr.width * transform.s * scene.camera.s,
                    physics.cr.height * transform.s * scene.camera.s,
                ),
                rl.Color.white,
            );
        }
    }

    fn drawDebugBlockSquare(scene: *const InitialScene) void {
        const squares: []const rl.Rectangle = &.{ getBlockSquareRect(rl.Vector2.init(-1, -1)), getBlockSquareRect(rl.Vector2.init(-1, 0)), getBlockSquareRect(rl.Vector2.init(0, -1)), getBlockSquareRect(rl.Vector2.init(0, 0)) };

        for (squares) |square| {
            const p = screen.screenPositionV(scene.camera.vxy(square.x, square.y));

            rl.drawRectangleV(p, rl.Vector2.init(square.width, square.height), rl.Color.white);
        }
    }
};
