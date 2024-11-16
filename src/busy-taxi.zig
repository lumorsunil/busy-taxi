const LoadError = @import("state.zig").LoadError;

const Scene = @import("scene.zig").Scene;

const textures = @import("textures.zig");
const texturePaths = textures.texturePaths;
const sounds = @import("sounds.zig");
const soundPaths = sounds.soundPaths;

pub const Game = struct {
    scene: ?Scene = null,

    pub fn init() Game {
        return Game{};
    }

    pub fn deinit(_: Game) void {}

    pub fn load(g: *Game) LoadError!void {
        if (g.scene) |scene| {
            try scene.load(texturePaths, soundPaths);
        }
    }

    pub fn setScene(g: *Game, scene: Scene) void {
        g.scene = scene;
    }

    pub fn update(g: *Game, dt: f32, t: f64) void {
        if (g.scene) |scene| {
            scene.update(dt, t);
        }
    }

    pub fn draw(g: *Game, dt: f32, t: f64) void {
        if (g.scene) |scene| {
            scene.draw(dt, t);
        }
    }
};
