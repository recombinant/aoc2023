const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const data = @embedFile("day6.txt");

    const margin = try getWinningCount(allocator, data);
    std.debug.print("margin of error is: {}\n", .{margin});
}

test "Wait For It" {
    const allocator = std.testing.allocator;

    const data = @embedFile("day6 sample.txt");

    try std.testing.expectEqual(@as(u32, 71503), try getWinningCount(allocator, data));
}

/// Using the quadratic equation
/// https://en.wikipedia.org/wiki/Quadratic_equation
/// The solution speeds lie between the two roots.
fn getWinningCount(allocator: Allocator, data: []const u8) !u32 {
    var it = std.mem.splitScalar(u8, data, '\n');
    const b = try getNumber(allocator, it.next().?); // time
    const c = try getNumber(allocator, it.next().?); // distance
    const delta = @sqrt(b * b - 4 * c);
    const root1 = (b - delta) / 2;
    const root2 = (b + delta) / 2;
    const min = @floor(root1 + 1);
    const max = @ceil(root2 - 1);
    return @intFromFloat(max - min + 1);
}

fn getNumber(allocator: Allocator, line: []const u8) !f64 {
    const colon = std.mem.indexOfScalar(u8, line, ':').?;
    const text = line[colon + 1 ..];

    var number_chars = std.ArrayList(u8).init(allocator);
    defer number_chars.deinit();
    for (text) |char|
        if (char != ' ')
            try number_chars.append(char);

    return try std.fmt.parseFloat(f64, number_chars.items);
}
