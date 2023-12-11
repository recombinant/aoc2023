const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const sum = try calculateSum(allocator, "data/day03.txt");
    std.debug.print("sum = {d}\n", .{sum});
}

test "Gear Ratios" {
    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(u32, 4361), try calculateSum(allocator, "data/day03 sample.txt"));
}

fn calculateSum(allocator: std.mem.Allocator, filename: []const u8) !u32 {
    const f = try std.fs.cwd().openFile(filename, .{});
    defer f.close();

    var buf_reader = std.io.bufferedReader(f.reader());
    var in_stream = buf_reader.reader();

    var lines = std.ArrayList([]const u8).init(allocator);
    defer lines.deinit();

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try lines.append(try allocator.dupe(u8, line));
    }

    const schematic = try lines.toOwnedSlice();
    defer {
        for (schematic) |line|
            allocator.free(line);
        allocator.free(schematic);
    }

    return try getPartsSum(schematic);
}

fn isSymbol(char: u8) bool {
    const not_symbol = "123456789.\n";
    return (null == std.mem.indexOfScalar(u8, not_symbol, char));
}

fn getPartsSum(schematic: []const []const u8) !u32 {
    var sum: u32 = 0;

    for (schematic, 0..) |line, row| {
        var col: usize = 0;
        while (col < line.len) {
            const char = line[col];
            if (std.ascii.isDigit(char)) {
                const len = getNumberLen(line, col);
                const number = try std.fmt.parseInt(u32, line[col .. col + len], 10);
                if (hasAdjacentSymbol(schematic, row, col, len))
                    sum += number;
                col += len;
            } else col += 1;
        }
    }
    return sum;
}

fn getNumberLen(line: []const u8, col: usize) usize {
    var len: usize = 0;
    for (line[col..]) |char| {
        if (!std.ascii.isDigit(char))
            break;
        len += 1;
    }
    return len;
}

fn hasAdjacentSymbol(schematic: []const []const u8, row: usize, col: usize, n: usize) bool {
    const line = schematic[row];

    const prev_line = if (row != 0) schematic[row - 1] else null;
    const next_line = if (row + 1 < schematic.len) schematic[row + 1] else null;

    if (col != 0) {
        if (isSymbol(line[col - 1]))
            return true;

        if (prev_line) |prev|
            for (prev[col - 1 .. col + n]) |char|
                if (isSymbol(char))
                    return true;

        if (next_line) |next|
            for (next[col - 1 .. col + n]) |char|
                if (isSymbol(char))
                    return true;
    }

    if (col + n < line.len) {
        if (isSymbol(line[col + n]))
            return true;

        if (next_line) |next|
            for (next[col .. col + n + 1]) |char|
                if (isSymbol(char))
                    return true;

        if (prev_line) |prev|
            for (prev[col .. col + n + 1]) |char|
                if (isSymbol(char))
                    return true;
    }
    return false;
}
