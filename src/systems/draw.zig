const std = @import("std");
const rl = @import("raylib");
const zlm = @import("zlm");

const GameState = @import("../state-config.zig").GameState;
const RigidBody = @import("../components.zig").RigidBody;
const Transform = @import("../components.zig").Transform;
const Invisible = @import("../components.zig").Invisible;
const Label = @import("../components.zig").Label;
const Camera = @import("../camera.zig").Camera;

const cfg = @import("../config.zig");

const screenPosition = @import("../screen.zig").screenPosition;
const screenPositionV = @import("../screen.zig").screenPositionV;

pub const DrawSystem = struct {
    pub fn printDebug(_: *const DrawSystem, s: *GameState) void {
        const orderedEntities = drawOrder(s);

        for (orderedEntities) |entity| {
            _ = s.getComponent(Transform, entity) catch continue;
            _ = s.getComponent(*const rl.Texture2D, entity) catch continue;
            const label = s.getComponent(Label, entity) catch continue;

            std.log.info("RENDERABLE ENTITY: {}: {s}", .{ entity, label.label });
        }
    }

    pub fn draw(self: *const DrawSystem, s: *GameState, camera: Camera) void {
        const orderedEntities = drawOrder(s);

        for (orderedEntities) |entity| {
            const invisible = s.getComponentO(Invisible, entity);

            if (invisible.* != null) continue;

            const transform = s.getComponent(Transform, entity) catch continue;
            const texture = s.getComponent(*const rl.Texture2D, entity) catch continue;

            DrawSystem.drawTexture(texture.*, transform.p, transform.r, transform.s, camera);
        }

        self.drawRigidBodies(s, camera);
    }

    pub fn drawRigidBodies(_: DrawSystem, s: *GameState, camera: Camera) void {
        for (0..s.entities.len) |entity| {
            const rigidBody = s.getComponent(RigidBody, entity) catch continue;
            DrawSystem.drawShape(rigidBody.*, camera);
        }
    }

    fn splice(comptime T: type, slice: []T, index: usize) []T {
        for (index..slice.len - 1) |i| {
            slice[i] = slice[i + 1];
        }

        return slice[0 .. slice.len - 1];
    }

    inline fn drawOrder(s: *GameState) []usize {
        var z: f32 = -std.math.inf(f32);
        var i: usize = 0;

        var sortedEntities: [cfg.MAX_ENTITIES]usize = undefined;
        var candidatesBuffer: [cfg.MAX_ENTITIES]usize = undefined;
        var candidates: []usize = candidatesBuffer[0..];

        for (0..s.entities.len) |entity| candidates[entity] = entity;

        for (0..s.entities.len) |_| {
            const lowest = getLowestZEntity(s, z, candidates) orelse break;
            const entity = candidates[lowest];
            const transform = s.getComponent(Transform, entity) catch continue;

            z = transform.p.y;
            sortedEntities[i] = entity;
            i += 1;
            candidates = splice(usize, candidates, lowest);
        }

        return sortedEntities[0..i];
    }

    fn getLowestZEntity(s: *GameState, z: f32, candidates: []usize) ?usize {
        var z_ = std.math.inf(f32);
        var lowest: ?usize = null;
        var i: usize = 0;

        for (candidates) |entity| {
            i += 1;
            const transform = s.getComponent(Transform, entity) catch continue;

            if (transform.p.y >= z and transform.p.y <= z_) {
                z_ = transform.p.y;
                lowest = i - 1;
            }
        }

        return lowest;
    }

    pub fn drawTexture(texture: *const rl.Texture2D, position: rl.Vector2, rotation: f32, scale: f32, camera: Camera) void {
        const s = scale * camera.s;
        const r = rotation + camera.angle();
        const w = @as(f32, @floatFromInt(texture.width));
        const h = @as(f32, @floatFromInt(texture.height));
        const p = rl.Vector2.init(position.x - (w / 2) * scale, position.y - (h / 2) * scale);

        const screenP = camera.v(screenPosition(p.x * camera.s, p.y * camera.s));
        const screenS = rl.Vector2.init(w * s, h * s);

        const source = rl.Rectangle.init(0, 0, w, h);
        const dest = rl.Rectangle.init(screenP.x, screenP.y, screenS.x, screenS.y);
        const origin = rl.Vector2.init(-dest.width / 2, -dest.height / 2);

        rl.drawTexturePro(texture.*, source, dest, origin, r, rl.Color.white);
    }

    pub fn drawShape(rb: RigidBody, camera: Camera) void {
        switch (rb.s.shape) {
            .circle => |circle| drawCircle(circle, rb, camera),
            .rectangle => |rectangle| drawRectangle(rectangle, rb, camera),
        }
    }

    pub fn drawCircle(circle: RigidBody.Shape.Circle, rb: RigidBody, camera: Camera) void {
        const s = camera.s;

        const screenP = camera.v(screenPosition(rb.d.p.x * s, rb.d.p.y * s));

        rl.drawCircleLinesV(screenP, circle.radius * s, rl.Color.white);
    }

    pub fn drawRectangle(rect: RigidBody.Shape.Rectangle, rb: RigidBody, camera: Camera) void {
        const s = camera.s;
        const p = rb.d.p.sub(rect.size.scale(1 / 2));

        const screenP = camera.v(screenPosition(p.x * camera.s, p.y * camera.s));
        const screenS = rect.size.scale(s);

        const dest = rl.Rectangle.init(screenP.x, screenP.y, screenS.x, screenS.y);

        rl.drawRectangleLinesEx(dest, 1, rl.Color.white);
    }

    fn drawDebugBorder(camera: Camera) void {
        const lw = 4;
        const lo = lw / 2;
        const tl = screenPositionV(camera.vxy(-lo, -lo));
        const br = screenPositionV(camera.vxy(cfg.size.w + lo, cfg.size.h + lo));

        const bl = rl.Vector2.init(tl.x, br.y);
        const tr = rl.Vector2.init(br.x, tl.y);

        rl.drawLineEx(tl, bl, lw, rl.Color.red);
        rl.drawLineEx(tl, tr, lw, rl.Color.red);
        rl.drawLineEx(bl, br, lw, rl.Color.red);
        rl.drawLineEx(tr, br, lw, rl.Color.red);
    }
};
