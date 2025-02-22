const std = @import("std");
const Textures = @import("textures.zig").Textures;
const Sounds = @import("sounds.zig").Sounds;
const Music = @import("music.zig").Music;
const LoadError = @import("state.zig").LoadError;

pub const Scene = struct {
    ptr: *anyopaque,
    vtable: SceneVTable,

    pub fn init(impl: anytype) Scene {
        const TPtr = @TypeOf(impl);
        const ti = @typeInfo(TPtr);
        const T = switch (ti) {
            .Pointer => |pointer| pointer.child,
            else => {
                @compileError("Implementation needs to be a pointer to a Scene implementation.");
            },
        };

        return Scene{
            .ptr = impl,
            .vtable = .{
                .load = T.load,
                .update = T.update,
                .draw = T.draw,
            },
        };
    }

    pub fn load(scene: Scene, texturePaths: Textures([*:0]const u8), soundPaths: Sounds([*:0]const u8), musicPaths: Music([*:0]const u8)) LoadError!void {
        return try scene.vtable.load(scene.ptr, texturePaths, soundPaths, musicPaths);
    }

    pub fn update(scene: Scene, dt: f32, t: f64) void {
        return scene.vtable.update(scene.ptr, dt, t);
    }

    pub fn draw(scene: Scene, dt: f32, t: f64) void {
        return scene.vtable.draw(scene.ptr, dt, t);
    }
};

const SceneVTable = struct {
    load: *const fn (scene: *anyopaque, texturePaths: Textures([*:0]const u8), soundPaths: Sounds([*:0]const u8), musicPaths: Music([*:0]const u8)) LoadError!void,
    update: *const fn (scene: *anyopaque, dt: f32, t: f64) void,
    draw: *const fn (scene: *anyopaque, dt: f32, t: f64) void,
};
