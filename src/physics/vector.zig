const std = @import("std");

pub const Vec2 = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) Vec2 {
        return Vec2{
            .x = x,
            .y = y,
        };
    }

    pub fn normal(self: Vec2) Vec2 {
        const a = std.math.atan2(self.y, self.x);
        self.x = std.math.cos(a);
        self.y = std.math.sin(a);
    }
};
