const std = @import("std");
const rl = @import("raylib");

pub const LoadError = error{
    FailedLoading,
    AlreadyLoaded,
};

pub const EntityError = error{
    IdUnavailable,
    NotFound,
};

pub const ComponentError = error{
    TypeNotFound,
    InstanceNotFound,
};

pub const StateConfig = struct {
    Textures: fn (comptime T: type) type,
    Sounds: fn (comptime T: type) type,
    Components: fn (comptime maxEntities: usize) type,
    maxEntities: usize,
};

pub fn State(comptime config: StateConfig) type {
    const maxEntities = config.maxEntities;
    const Textures = config.Textures;
    const Sounds = config.Sounds;
    const Components = config.Components;

    if (!std.meta.hasMethod(Components(maxEntities), "get")) {
        @compileError("State: config.Components needs to implement fn get(comptime ComponentType: type, entity: usize) ComponentError!*ComponentType");
    }

    if (!std.meta.hasMethod(Components(maxEntities), "getOptional")) {
        @compileError("State: config.Components needs to implement fn getOptional(comptime ComponentType: type, entity: usize) ComponentError!*?ComponentType");
    }

    return struct {
        entities: [maxEntities]?bool = undefined,

        textures: Textures(rl.Texture2D) = undefined,
        sounds: Sounds(rl.Sound) = undefined,

        components: Components(maxEntities) = Components(maxEntities){},

        isLoaded: bool = false,

        const Self = @This();

        pub fn init() Self {
            return .{};
        }

        pub fn load(s: *Self, texturePaths: Textures([*:0]const u8), soundPaths: Sounds([*:0]const u8)) LoadError!void {
            if (s.isLoaded) {
                return LoadError.AlreadyLoaded;
            }

            inline for (std.meta.fields(@TypeOf(texturePaths))) |field| {
                @field(s.textures, field.name) = rl.loadTexture(@field(texturePaths, field.name));
            }

            inline for (std.meta.fields(@TypeOf(soundPaths))) |field| {
                const sound = rl.loadSound(@field(soundPaths, field.name));
                @field(s.sounds, field.name) = sound;
                rl.setSoundVolume(sound, 0.02);
            }

            s.isLoaded = true;
        }

        pub fn deinit(s: *Self) void {
            inline for (std.meta.fields(@TypeOf(s.textures))) |field| {
                rl.unloadTexture(@field(s.textures, field.name));
            }

            inline for (std.meta.fields(@TypeOf(s.sounds))) |field| {
                rl.unloadSound(@field(s.sounds, field.name));
            }
        }

        fn getAvailableEntityId(s: *const Self) EntityError!usize {
            for (0.., s.entities) |i, maybeEntity| {
                if (maybeEntity != null) continue;
                return i;
            }

            return EntityError.IdUnavailable;
        }

        pub fn addEntity(s: *Self) EntityError!usize {
            const id = try s.getAvailableEntityId();

            s.entities[id] = true;

            return id;
        }

        pub fn destroyEntity(s: *Self, entity: usize) EntityError!void {
            if (s.entities[entity] == null) return EntityError.NotFound;
            s.entities[entity] = null;

            inline for (std.meta.fields(@TypeOf(s.components))) |field| {
                @field(s.components, field.name)[entity] = null;
            }
        }

        pub fn destroyAllEntities(s: *Self) void {
            for (0..s.entities.len) |i| {
                s.entities[i] = null;

                inline for (std.meta.fields(@TypeOf(s.components))) |field| {
                    @field(s.components, field.name)[i] = null;
                }
            }
        }

        pub fn doesEntityExist(s: *const Self, entity: usize) bool {
            return s.entities[entity] != null;
        }

        pub fn getComponent(s: *Self, comptime T: type, entity: usize) ComponentError!*T {
            return try s.components.get(T, entity);
        }

        pub fn getComponentO(s: *Self, comptime T: type, entity: usize) *?T {
            return s.components.getOptional(T, entity);
        }

        pub fn setComponent(s: *Self, comptime T: type, entity: usize, componentData: T) void {
            const component = s.getComponentO(T, entity);
            component.* = componentData;
        }

        pub fn removeComponent(s: *Self, comptime T: type, entity: usize) void {
            const component = s.getComponentO(T, entity);
            component.* = null;
        }
    };
}
