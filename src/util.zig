const std = @import("std");
const ecs = @import("ecs");
const zlm = @import("zlm");
const zge = @import("zge");
const V = zge.vector.V;
const Vector = zge.vector.Vector;

pub const piHalf: f32 = std.math.pi / @as(f32, 2);
pub const Direction = struct {
    pub const right: f32 = 0;
    pub const up: f32 = piHalf;
    pub const left: f32 = @as(f32, std.math.pi);
    pub const down: f32 = piHalf * 3;
};

pub fn random(reg: *ecs.Registry) std.Random.Random {
    return reg.singletons().get(std.Random.DefaultPrng).random();
}

pub fn minLength(v: Vector, len: f32) Vector {
    const currentLen = V.length(v);
    const targetLen = @max(currentLen, len);
    return V.normalize(v) * V.scalar(targetLen);
}
