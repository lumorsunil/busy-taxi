const std = @import("std");

pub const Direction = struct {
    r: f32 = RIGHT,

    pub const RIGHT = 0;
    pub const RIGHT_2 = std.math.pi * 2;
    pub const DOWN = std.math.pi / @as(f32, 2);
    pub const LEFT = std.math.pi;
    pub const UP = (std.math.pi / @as(f32, 2)) * 3;

    const epsilon = 0.05;

    pub fn set(self: *Direction, r: f32) void {
        self.r = normalizeRadians(r);
    }

    pub fn setRight(self: *Direction) void {
        self.r = RIGHT;
    }

    pub fn setUp(self: *Direction) void {
        self.r = UP;
    }

    pub fn setLeft(self: *Direction) void {
        self.r = LEFT;
    }

    pub fn setDown(self: *Direction) void {
        self.r = DOWN;
    }

    pub fn isHorizontal(self: Direction) bool {
        return self.isRight() or self.isLeft();
    }

    pub fn isVertical(self: Direction) bool {
        return self.isUp() or self.isDown();
    }

    fn normalizeRadians(r: f32) f32 {
        var r_ = r;

        while (r_ < 0) {
            r_ += std.math.pi * 2;
        }

        while (r_ >= std.math.pi * 2) {
            r_ -= std.math.pi * 2;
        }

        return r_;
    }

    pub fn approxEqAbs(self: Direction, r: f32) bool {
        return std.math.approxEqAbs(f32, self.r, normalizeRadians(r), epsilon);
    }

    pub fn approxEqRel(self: Direction, r: f32) bool {
        return std.math.approxEqRel(f32, self.r, normalizeRadians(r), epsilon);
    }

    pub fn approxEq(self: Direction, r: f32) bool {
        return self.approxEqRel(r) or self.approxEqAbs(r);
    }

    pub fn isRight(self: Direction) bool {
        return self.approxEqAbs(RIGHT) or self.approxEqRel(RIGHT_2);
    }

    pub fn isUp(self: Direction) bool {
        return self.approxEqRel(UP);
    }

    pub fn isLeft(self: Direction) bool {
        return self.approxEqRel(LEFT);
    }

    pub fn isDown(self: Direction) bool {
        return self.approxEqRel(DOWN);
    }
};
