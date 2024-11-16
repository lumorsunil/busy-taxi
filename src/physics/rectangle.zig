const zlm = @import("zlm");

pub const Rect = struct {
    tl: zlm.Vec2,
    br: zlm.Vec2,

    pub fn init(x: f32, y: f32, w: f32, h: f32) Rect {
        return Rect{
            .tl = zlm.vec2(x, y),
            .br = zlm.vec2(x + w, y + h),
        };
    }

    pub fn area(self: Rect) f32 {
        return self.width() * self.height();
    }

    pub fn width(self: Rect) f32 {
        return self.right() - self.left();
    }

    pub fn height(self: Rect) f32 {
        return self.bottom() - self.top();
    }

    pub fn left(self: Rect) f32 {
        return self.tl.x;
    }

    pub fn right(self: Rect) f32 {
        return self.br.x;
    }

    pub fn top(self: Rect) f32 {
        return self.tl.y;
    }

    pub fn bottom(self: Rect) f32 {
        return self.br.y;
    }

    pub fn aabb(self: Rect, other: Rect) bool {
        return self.left() < other.right() and self.top() < other.bottom() and
            other.left() < self.right() and other.top() < self.bottom();
    }
};
