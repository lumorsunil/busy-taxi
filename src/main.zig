const std = @import("std");
const rl = @import("raylib");
const zlm = @import("zlm");

const Game = @import("busy-taxi.zig").Game;

const InitialScene = @import("scenes/initial.zig").InitialScene;
const Scene = @import("scene.zig").Scene;

const cfg = @import("config.zig");
const zge = @import("zge");
const V = zge.vector.V;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var game = Game.init();
    defer game.deinit();

    var screen = zge.screen.Screen.init(.{ cfg.initialSize.w, cfg.initialSize.h });

    const sizeX, const sizeY = V.toInt(i32, screen.size);
    rl.initWindow(sizeX, sizeY, "Busy Taxi");
    defer rl.closeWindow();
    rl.setWindowState(.{ .vsync_hint = true });
    rl.setWindowPosition(cfg.initialPosition.x, cfg.initialPosition.y);
    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    var initialScene = InitialScene.init(allocator, &screen);
    defer initialScene.deinit();
    game.setScene(Scene.init(&initialScene));

    game.load() catch |err| {
        std.debug.print("Error: {}\n", .{err});
        const maybeStackTrace = @errorReturnTrace();
        if (maybeStackTrace) |stackTrace| std.debug.dumpStackTrace(stackTrace.*);
        std.process.exit(1);
        return err;
    };

    while (!rl.windowShouldClose()) {
        const t = rl.getTime();
        const dt = rl.getFrameTime();

        if (rl.isWindowResized()) {
            screen.setSize(V.fromInt(i32, rl.getScreenWidth(), rl.getScreenHeight()));
        }

        game.update(dt, t);
        game.draw(dt, t);
    }
}
