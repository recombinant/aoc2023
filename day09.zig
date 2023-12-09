// AOC 2023 Day 09 Mirage Maintenance
const std = @import("std");

pub fn main() !void {
    const data = @embedFile("day09.txt");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const answer1 = try getAnswer(allocator, data, false);
    const answer2 = try getAnswer(allocator, data, true);
    std.debug.print("{}\n", .{answer1});
    std.debug.print("{}\n", .{answer2});
}

test "Mirage Maintenance part 1" {
    const data = @embedFile("day09 sample.txt");

    const allocator = std.testing.allocator;

    const answer = try getAnswer(allocator, data, false);

    try std.testing.expectEqual(@as(i32, 114), answer);
}

test "Mirage Maintenance part 2" {
    const data = @embedFile("day09 sample.txt");

    const allocator = std.testing.allocator;

    const answer = try getAnswer(allocator, data, true);

    try std.testing.expectEqual(@as(i32, 2), answer);
}

/// Return the sum of the answers for each line.
fn getAnswer(allocator: std.mem.Allocator, data: []const u8, comptime is_part2: bool) !i32 {
    var answer: i32 = 0;

    var value_history = std.ArrayList(i32).init(allocator);
    defer value_history.deinit();

    var line_it = std.mem.splitScalar(u8, data, '\n');
    while (line_it.next()) |line| {
        var value_it = std.mem.splitScalar(u8, line, ' ');
        while (value_it.next()) |value|
            try value_history.append(try std.fmt.parseInt(i32, value, 10));
        answer += try evaluateValues(allocator, value_history.items, is_part2);
        value_history.clearRetainingCapacity();
    }
    return answer;
}

fn evaluateValues(allocator: std.mem.Allocator, values: []const i32, comptime is_part2: bool) !i32 {
    var differences_list = std.ArrayList(i32).init(allocator);
    defer differences_list.deinit();

    for (0..values.len - 1) |idx|
        try differences_list.append(values[idx + 1] - values[idx]);

    const diffs = differences_list.items;

    const all_zero = for (diffs) |d| {
        if (d != 0) break false;
    } else true;

    if (!all_zero) {
        const evaluated = try evaluateValues(allocator, diffs, is_part2);
        for (diffs) |d| {
            if (d == 0)
                continue;
            if (is_part2)
                return values[0] - evaluated
            else
                return values[values.len - 1] + evaluated;
        }
    }

    return if (is_part2) values[0] else values[values.len - 1];
}
