const std = @import("std");
const Allocator = std.mem.Allocator;

const cfg = @import("config.zig");

pub const HighscoreEntry = struct {
    name: [16:0]u8 = .{0} ** 16,
    score: usize = 0,
};

pub const Highscore = struct {
    leaderboard: [cfg.MAX_HIGHSCORE_ENTRIES]HighscoreEntry = [_]HighscoreEntry{HighscoreEntry{}} ** cfg.MAX_HIGHSCORE_ENTRIES,
    parsed: ?std.json.Parsed([cfg.MAX_HIGHSCORE_ENTRIES]HighscoreEntry) = null,

    pub fn loadHighscore(allocator: Allocator) !Highscore {
        var buffer: [4096]u8 = undefined;

        const contents = std.fs.cwd().readFile(cfg.highScorePath, &buffer) catch |err| switch (err) {
            std.fs.Dir.OpenError.FileNotFound => return Highscore{},
            else => return err,
        };
        const parsed = try std.json.parseFromSlice([cfg.MAX_HIGHSCORE_ENTRIES]HighscoreEntry, allocator, contents, .{});

        return Highscore{
            .leaderboard = parsed.value,
            .parsed = parsed,
        };
    }

    pub fn saveHighscore(self: *const Highscore) !void {
        const file = try std.fs.cwd().createFile(cfg.highScorePath, .{});
        defer file.close();
        try std.json.stringify(self.leaderboard, .{}, file.writer());
    }

    pub fn insertHighscoreIfEligible(self: *Highscore, score: usize) !void {
        if (!self.isEligibleForHighscore(score)) return;

        const ri = self.scorePlacement(score) - 1;

        if (ri < self.leaderboard.len - 1) {
            for (ri + 1..self.leaderboard.len - 1) |i| {
                self.leaderboard[i + 1] = self.leaderboard[i];
            }
        }

        self.leaderboard[ri] = HighscoreEntry{ .score = score };

        try self.saveHighscore();
    }

    pub fn scorePlacement(self: *const Highscore, score: usize) usize {
        for (0..self.leaderboard.len) |entry| {
            if (self.leaderboard[entry].score < score) return entry + 1;
        }

        return 0;
    }

    pub fn isEligibleForHighscore(self: *const Highscore, score: usize) bool {
        return self.leaderboard[self.leaderboard.len - 1].score < score;
    }

    pub fn deinit(self: *Highscore) void {
        if (self.parsed) |parsed| parsed.deinit();
    }
};
