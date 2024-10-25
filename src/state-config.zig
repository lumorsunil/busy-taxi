const rl = @import("raylib");

const State = @import("state.zig").State;
const StateConfig = @import("state.zig").StateConfig;

const cfg = @import("config.zig");

const Textures = @import("textures.zig").Textures;
const Sounds = @import("sounds.zig").Sounds;
const Components = @import("components.zig").Components;

pub const stateConfig: StateConfig = .{
    .Textures = Textures,
    .Sounds = Sounds,
    .Components = Components,
    .maxEntities = cfg.MAX_ENTITIES,
};

pub const GameState = State(stateConfig);

pub fn stateTextures(state: *const GameState) *const Textures(rl.Texture2D) {
    return &state.textures;
}
