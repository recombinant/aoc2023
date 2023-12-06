const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const data = @embedFile("day6.txt");

    const margin = try getMargin(allocator, data);
    std.debug.print("margin of error is: {}\n", .{margin});
}

test "Wait For It" {
    const allocator = std.testing.allocator;

    const data = @embedFile("day6 sample.txt");

    try std.testing.expectEqual(@as(u32, 288), try getMargin(allocator, data));
}

fn getMargin(allocator: Allocator, data: []const u8) !u32 {
    var it = std.mem.splitScalar(u8, data, '\n');
    const times = try getNumbers(allocator, it.next().?);
    const distances = try getNumbers(allocator, it.next().?);
    defer allocator.free(times);
    defer allocator.free(distances);

    var margin: ?u32 = null;
    for (times, distances) |t, d| {
        const count = getWinningCount(t, d);
        margin = if (margin) |m| m * count else count;
    }

    return if (margin) |m| m else 0;
}

/// Caller owns returned slice memory.
fn getNumbers(allocator: Allocator, line: []const u8) ![]u32 {
    const colon = std.mem.indexOfScalar(u8, line, ':').?;
    var it = std.mem.tokenizeScalar(u8, line[colon + 1 ..], ' ');

    var numbers = std.ArrayList(u32).init(allocator);
    while (it.next()) |text| {
        const number = try std.fmt.parseInt(u32, text, 10);
        try numbers.append(number);
    }
    return try numbers.toOwnedSlice();
}

/// Using the quadratic equation
/// https://en.wikipedia.org/wiki/Quadratic_equation
/// The solution speeds lie between the two roots.
fn getWinningCount(time: u32, distance: u32) u32 {
    const b: f64 = @floatFromInt(time);
    const c: f64 = @floatFromInt(distance);
    const delta = @sqrt(b * b - 4 * c);
    const root1 = (b - delta) / 2;
    const root2 = (b + delta) / 2;
    const min = @floor(root1 + 1);
    const max = @ceil(root2 - 1);
    return @intFromFloat(max - min + 1);
}
