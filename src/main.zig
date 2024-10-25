const std = @import("std");
const rl = @import("raylib");

const Game = @import("crazy-taxi.zig").Game;

const Scene = @import("scene.zig").Scene;
const InitialScene = @import("scenes/initial.zig").InitialScene;

const cfg = @import("config.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var game = Game.init();
    defer game.deinit();

    rl.initWindow(cfg.size.w, cfg.size.h, "Crazy Taxi");
    rl.setWindowState(.{ .vsync_hint = true });
    defer rl.closeWindow();
    rl.setWindowPosition(15, 100);
    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    game.load() catch |err| {
        std.debug.print("Error: {}\n", .{err});
        const maybeStackTrace = @errorReturnTrace();
        if (maybeStackTrace) |stackTrace| std.debug.dumpStackTrace(stackTrace.*);
        std.process.exit(1);
        return err;
    };

    var initialScene = InitialScene.init(allocator, &game.state) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        const maybeStackTrace = @errorReturnTrace();
        if (maybeStackTrace) |stackTrace| std.debug.dumpStackTrace(stackTrace.*);
        std.process.exit(1);
    };
    defer initialScene.deinit();

    game.setScene(Scene.from(InitialScene, &initialScene));

    while (!rl.windowShouldClose()) {
        const t = rl.getTime();
        const dt = rl.getFrameTime();

        try game.update(dt, t);
        game.draw();
    }
}
