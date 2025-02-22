const cfg = @import("config.zig");
const assetsRoot = cfg.assetsRoot;

pub fn Music(comptime T: type) type {
    return struct {
        theme: T,
    };
}

pub const musicPaths = Music([*:0]const u8){
    .theme = assetsRoot ++ "busy-taxi.wav",
};
