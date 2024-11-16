const std = @import("std");
const rl = @import("raylib");
const zlm = @import("zlm");

const Game = @import("busy-taxi.zig").Game;

const InitialScene = @import("scenes/initial.zig").InitialScene;
const Scene = @import("scene.zig").Scene;

const cfg = @import("config.zig");
const zge = @import("zge");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var game = Game.init();
    defer game.deinit();

    var screen = zge.screen.Screen.init(cfg.initialSize.w, cfg.initialSize.h);

    const sizeAsInt = screen.asInt(i32);
    rl.initWindow(sizeAsInt.x, sizeAsInt.y, "Busy Taxi");
    rl.setWindowState(.{ .vsync_hint = true });
    defer rl.closeWindow();
    rl.setWindowPosition(15, 100);
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
            screen.setSizeFromInt(i32, zlm.SpecializeOn(i32).vec2(rl.getScreenWidth(), rl.getScreenHeight()));
        }

        game.update(dt, t);
        game.draw(dt, t);
    }
}
