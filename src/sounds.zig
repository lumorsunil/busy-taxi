const cfg = @import("config.zig");
const assetsRoot = cfg.assetsRoot;

pub fn Sounds(comptime T: type) type {
    return struct {
        engine: T,
        hardTurn: T,
        horn: T,
        crash: T,
        score: T,
    };
}

pub const soundPaths = Sounds([*:0]const u8){
    .engine = assetsRoot ++ "Engine.wav",
    .hardTurn = assetsRoot ++ "HardTurn.wav",
    .horn = assetsRoot ++ "Horn.wav",
    .crash = assetsRoot ++ "Crash.wav",
    .score = assetsRoot ++ "Score.wav",
};
