const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const sum = try calculateSum(allocator, "data/day3.txt");
    std.debug.print("sum = {d}\n", .{sum});
}

test "Gear Ratios" {
    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(u32, 467835), try calculateSum(allocator, "data/day3 sample.txt"));
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

    return try getRatiosSum(allocator, schematic);
}

fn getRatiosSum(allocator: std.mem.Allocator, schematic: []const []const u8) !u32 {
    var sum: u32 = 0;

    // Find the * symbols and gears adjacent thereto.
    for (schematic, 0..) |line, row| {
        var col: usize = 0;
        while (col < line.len) {
            const char = line[col];
            if (char == '*') {
                const numbers: []const []const u8 = try getAdjacentNumbers(allocator, schematic, row, col);
                if (numbers.len == 2) {
                    const number1 = try std.fmt.parseInt(u32, numbers[0], 10);
                    const number2 = try std.fmt.parseInt(u32, numbers[1], 10);
                    sum += number1 * number2;
                }
                allocator.free(numbers);
            }
            col += 1;
        }
    }
    return sum;
}

// Caller owns returned slice memory.
fn getAdjacentNumbers(allocator: std.mem.Allocator, schematic: []const []const u8, row: usize, col: usize) ![]const []const u8 {
    var numbers = std.ArrayList(?[]const u8).init(allocator);
    defer numbers.deinit();

    std.debug.assert(schematic[row][col] == '*');

    {
        const line = schematic[row];
        // Check west and east
        if (col != 0)
            try numbers.append(getNumber(line, col - 1));
        if (col + 1 < line.len)
            try numbers.append(getNumber(line, col + 1));
    }
    // Check north, failing that check north-west and north-east
    if (row != 0) {
        const line = schematic[row - 1];
        const optional_number = getNumber(line, col);
        if (optional_number) |_|
            try numbers.append(optional_number)
        else {
            if (col != 0)
                try numbers.append(getNumber(line, col - 1));
            if (col + 1 < line.len)
                try numbers.append(getNumber(line, col + 1));
        }
    }
    if (row + 1 < schematic.len) {
        // Check south, failing that check south-west and south-east
        const line = schematic[row + 1];
        const optional_number = getNumber(line, col);
        if (optional_number) |_|
            try numbers.append(optional_number)
        else {
            if (col != 0)
                try numbers.append(getNumber(line, col - 1));
            if (col + 1 < line.len)
                try numbers.append(getNumber(line, col + 1));
        }
    }
    {
        // Filter out nulls.
        // Filtered here as otherwise cluttered if() statements will clutter the code.
        var i = numbers.items.len;
        while (i != 0) {
            i -= 1;
            if (numbers.items[i] == null)
                _ = numbers.swapRemove(i);
        }
    }

    const result = try allocator.alloc([]const u8, numbers.items.len);
    for (numbers.items, 0..) |number, i| {
        result[i] = number.?;
    }

    return result;
}

fn getNumber(line: []const u8, col: usize) ?[]const u8 {
    const isDigit = std.ascii.isDigit;

    if (!isDigit(line[col]))
        return null;

    var col0 = col;
    var col1 = col;

    while (col0 > 0) {
        if (!isDigit(line[col0 - 1]))
            break;
        col0 -= 1;
    }
    while (col1 < line.len) {
        if (!isDigit(line[col1]))
            break;
        col1 += 1;
    }
    return line[col0..col1];
}
