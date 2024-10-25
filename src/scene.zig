const InitialScene = @import("scenes/initial.zig").InitialScene;

pub const Scene = union(enum) {
    initialScene: *InitialScene,

    pub fn from(comptime T: type, scene: *T) Scene {
        return switch (T) {
            InitialScene => return Scene{ .initialScene = scene },
            else => @compileError("Invalid Scene type " ++ @typeName(T)),
        };
    }
};
