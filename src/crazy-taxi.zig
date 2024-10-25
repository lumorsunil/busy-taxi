const rl = @import("raylib");

const LoadError = @import("state.zig").LoadError;

const textures = @import("textures.zig");
const texturePaths = textures.texturePaths;
const sounds = @import("sounds.zig");
const soundPaths = sounds.soundPaths;

const GameState = @import("state-config.zig").GameState;

const Scene = @import("scene.zig").Scene;

pub const Game = struct {
    state: GameState,
    scene: ?Scene = null,

    pub fn init() Game {
        return Game{
            .state = GameState.init(),
        };
    }

    pub fn deinit(g: *Game) void {
        g.state.deinit();
    }

    pub fn load(g: *Game) LoadError!void {
        try g.state.load(texturePaths, soundPaths);
    }

    pub fn destroyScene(g: *Game) void {
        g.scene = null;
        g.state.destroyAllEntities();
    }

    pub fn setScene(g: *Game, scene: Scene) void {
        g.scene = scene;
    }

    pub fn switchScene(g: *Game, scene: Scene) void {
        g.destroyScene();
        g.setScene(scene);
    }

    pub fn update(g: *Game, dt: f32, t: f64) !void {
        if (g.scene) |*scene| {
            switch (scene.*) {
                Scene.initialScene => |initialScene| try initialScene.update(&g.state, dt, t),
            }
        }
    }

    pub fn draw(g: *Game) void {
        if (g.scene) |*scene| {
            switch (scene.*) {
                Scene.initialScene => |initialScene| initialScene.draw(&g.state),
            }
        }
    }
};
