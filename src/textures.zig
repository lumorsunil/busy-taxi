const cfg = @import("config.zig");
const assetsRoot = cfg.assetsRoot;

pub fn Textures(comptime T: type) type {
    return struct {
        playerLeft1: T,
        playerLeft2: T,
        playerRight1: T,
        playerRight2: T,
        playerUp1: T,
        playerUp2: T,
        playerDown1: T,
        playerDown2: T,

        roadUp: T,
        roadDown: T,
        roadLeft: T,
        roadRight: T,
        roadIntersectionTopLeft: T,
        roadIntersectionTopRight: T,
        roadIntersectionBottomLeft: T,
        roadIntersectionBottomRight: T,
        roadCornerTopLeft: T,
        roadCornerTopRight: T,
        roadCornerBottomLeft: T,
        roadCornerBottomRight: T,

        houseBlue: T,
        houseGreen: T,
        houseOrange: T,
        houseRed: T,
        park: T,

        fenceX: T,
        fenceY: T,
        fenceTopLeft: T,
        fenceTopRight: T,
        fenceBottomLeft: T,
        fenceBottomRight: T,

        pedestrianBlueIdle: T,
        pedestrianBlueWalk1: T,
        pedestrianBlueWalk2: T,
        pedestrianBlueWalk3: T,
        pedestrianBlueWalk4: T,

        pedestrianRedIdle: T,
        pedestrianRedWalk1: T,
        pedestrianRedWalk2: T,
        pedestrianRedWalk3: T,
        pedestrianRedWalk4: T,
    };
}

pub const texturePaths = Textures([*:0]const u8){
    .playerLeft1 = assetsRoot ++ "player-left-1.png",
    .playerLeft2 = assetsRoot ++ "player-left-2.png",
    .playerRight1 = assetsRoot ++ "player-right-1.png",
    .playerRight2 = assetsRoot ++ "player-right-2.png",
    .playerUp1 = assetsRoot ++ "player-up-1.png",
    .playerUp2 = assetsRoot ++ "player-up-2.png",
    .playerDown1 = assetsRoot ++ "player-down-1.png",
    .playerDown2 = assetsRoot ++ "player-down-2.png",

    .roadUp = assetsRoot ++ "road-up.png",
    .roadDown = assetsRoot ++ "road-down.png",
    .roadLeft = assetsRoot ++ "road-left.png",
    .roadRight = assetsRoot ++ "road-right.png",
    .roadIntersectionTopLeft = assetsRoot ++ "road-intersection-top-left.png",
    .roadIntersectionTopRight = assetsRoot ++ "road-intersection-top-right.png",
    .roadIntersectionBottomLeft = assetsRoot ++ "road-intersection-bottom-left.png",
    .roadIntersectionBottomRight = assetsRoot ++ "road-intersection-bottom-right.png",
    .roadCornerTopLeft = assetsRoot ++ "road-corner-top-left.png",
    .roadCornerTopRight = assetsRoot ++ "road-corner-top-right.png",
    .roadCornerBottomLeft = assetsRoot ++ "road-corner-bottom-left.png",
    .roadCornerBottomRight = assetsRoot ++ "road-corner-bottom-right.png",

    .houseBlue = assetsRoot ++ "house-blue.png",
    .houseGreen = assetsRoot ++ "house-green.png",
    .houseOrange = assetsRoot ++ "house-orange.png",
    .houseRed = assetsRoot ++ "house-red.png",
    .park = assetsRoot ++ "park.png",

    .fenceX = assetsRoot ++ "fence-left.png",
    .fenceY = assetsRoot ++ "fence-top.png",
    .fenceTopLeft = assetsRoot ++ "fence-top-left.png",
    .fenceTopRight = assetsRoot ++ "fence-top-right.png",
    .fenceBottomLeft = assetsRoot ++ "fence-bottom-left.png",
    .fenceBottomRight = assetsRoot ++ "fence-bottom-right.png",

    .pedestrianBlueIdle = assetsRoot ++ "pedestrian-blue.png",
    .pedestrianBlueWalk1 = assetsRoot ++ "pedestrian-blue-walk-1.png",
    .pedestrianBlueWalk2 = assetsRoot ++ "pedestrian-blue-walk-2.png",
    .pedestrianBlueWalk3 = assetsRoot ++ "pedestrian-blue-walk-3.png",
    .pedestrianBlueWalk4 = assetsRoot ++ "pedestrian-blue-walk-4.png",

    .pedestrianRedIdle = assetsRoot ++ "pedestrian-red.png",
    .pedestrianRedWalk1 = assetsRoot ++ "pedestrian-red-walk-1.png",
    .pedestrianRedWalk2 = assetsRoot ++ "pedestrian-red-walk-2.png",
    .pedestrianRedWalk3 = assetsRoot ++ "pedestrian-red-walk-3.png",
    .pedestrianRedWalk4 = assetsRoot ++ "pedestrian-red-walk-4.png",
};
