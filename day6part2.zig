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

fn getWinningCount(allocator: Allocator, data: []const u8) !u32 {
    var it = std.mem.splitScalar(u8, data, '\n');
    const time = try getNumber(allocator, it.next().?);
    const max_distance = try getNumber(allocator, it.next().?);

    // This could be optimized as the output is symetrical.
    var count: u32 = 0;
    for (1..time) |button_time| {
        const speed = button_time;
        const duration = time - button_time;
        const distance = speed * duration;
        if (distance > max_distance)
            count += 1;
    }
    return count;
}

fn getNumber(allocator: Allocator, line: []const u8) !u64 {
    const colon = std.mem.indexOfScalar(u8, line, ':').?;
    const text = line[colon + 1 ..];

    var number_chars = std.ArrayList(u8).init(allocator);
    defer number_chars.deinit();
    for (text) |char|
        if (char != ' ')
            try number_chars.append(char);

    return try std.fmt.parseInt(u64, number_chars.items, 10);
}
