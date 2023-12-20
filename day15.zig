// AOC 2023 Day 15: Lens Library
// from
// https://github.com/womogenes/AoC-2023-Solutions/tree/main/day_15
//
const std = @import("std");

pub fn main() !void {
    const data = @embedFile("data/day15.txt");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const answer1 = getAnswer1(data);
    const answer2 = try getAnswer2(allocator, data);
    std.debug.print("{}\n", .{answer1});
    std.debug.print("{}\n", .{answer2});
}

test "Lens Library part 1" {
    const data = @embedFile("data/day15 sample.txt");

    const answer = getAnswer1(data);

    try std.testing.expectEqual(@as(u32, 1320), answer);
}

test "Lens Library part 2" {
    const data = @embedFile("data/day15 sample.txt");

    const allocator = std.testing.allocator;

    const answer = try getAnswer2(allocator, data);

    try std.testing.expectEqual(@as(u32, 145), answer);
}

fn hash(s: []const u8) u16 {
    var cur: u16 = 0;
    for (s) |c| {
        cur += c;
        cur *= 17;
        cur %= 256;
    }
    return cur;
}

fn getAnswer1(data: []const u8) u32 {
    var answer: u32 = 0;

    var part_it = std.mem.splitScalar(u8, data, ',');
    while (part_it.next()) |part|
        answer += hash(part);

    return answer;
}

fn getAnswer2(allocator: std.mem.Allocator, data: []const u8) !u32 {
    var answer: usize = 0;

    var boxes: [256]Box = undefined;
    for (&boxes) |*box|
        box.* = Box.init(allocator);
    defer for (&boxes) |*box| box.contents.deinit();

    try getBoxes(&boxes, data);

    for (&boxes, 1..) |box, i| {
        var power: usize = 0;
        for (box.contents.items, 1..) |lens, j|
            power += i * j * lens.focal_length;

        answer += power;
    }
    return @intCast(answer);
}

fn getBoxes(boxes: []Box, data: []const u8) !void {
    var part_it = std.mem.splitScalar(u8, data, ',');
    while (part_it.next()) |part| {
        const idx = std.mem.indexOfAny(u8, part, "-=").?;
        const label = part[0..idx];
        var box = &boxes[hash(label)];
        switch (part[idx]) {
            '-' => box.remove(label),
            '=' => {
                std.debug.assert(part[idx + 1 ..].len == 1);
                const focal_length = part[idx + 1] - '0';
                try box.update(label, focal_length);
            },
            else => unreachable,
        }
    }
}

const Lens = struct {
    label: []const u8, // slice of data
    focal_length: u32,
};

const Box = struct {
    contents: std.ArrayList(Lens),

    fn init(allocator: std.mem.Allocator) Box {
        return Box{
            .contents = std.ArrayList(Lens).init(allocator),
        };
    }
    fn deinit(self: *Box) void {
        self.contents.deinit();
    }

    /// Try to find a lens by label (linear search).
    /// - found: replace the lens
    /// - not found: append the lens
    fn update(self: *Box, label: []const u8, focal_length: u8) !void {
        for (self.contents.items) |*lens| {
            if (std.mem.eql(u8, lens.label, label)) {
                lens.*.focal_length = focal_length;
                return;
            }
        }
        const lens = Lens{
            .label = label,
            .focal_length = focal_length,
        };
        try self.contents.append(lens);
    }
    /// Try to find a lens by label (linear search).
    /// - found: remove lens
    /// - not found: do nothing
    fn remove(self: *Box, label: []const u8) void {
        for (self.contents.items, 0..) |lens, idx| {
            if (std.mem.eql(u8, lens.label, label)) {
                _ = self.contents.orderedRemove(idx);
                return;
            }
        }
    }
};
