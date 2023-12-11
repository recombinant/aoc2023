const std = @import("std");

const Numbers = std.bit_set.ArrayBitSet(usize, 100);

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const scratchcards = try ScratchCards.init(allocator, "data/day4.txt");
    defer scratchcards.deinit();

    const total = scratchcards.getPointsTotal();

    try stdout.print("points total = {}\n", .{total});
}

test "Scratchcards" {
    const allocator = std.testing.allocator;

    const scratchcards = try ScratchCards.init(allocator, "data/day4 sample.txt");
    defer scratchcards.deinit();

    try std.testing.expectEqual(@as(u32, 13), scratchcards.getPointsTotal());
}

const ScratchCards = struct {
    allocator: std.mem.Allocator,
    lines: []const []const u8,

    fn init(allocator: std.mem.Allocator, filename: []const u8) !ScratchCards {
        const f = try std.fs.cwd().openFile(filename, .{});
        defer f.close();

        var buf_reader = std.io.bufferedReader(f.reader());
        var in_stream = buf_reader.reader();

        var lines_array_list = std.ArrayList([]const u8).init(allocator);
        defer lines_array_list.deinit();

        var buf: [1024]u8 = undefined;
        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            try lines_array_list.append(try allocator.dupe(u8, line));
        }

        const lines = try lines_array_list.toOwnedSlice();
        return ScratchCards{
            .allocator = allocator,
            .lines = lines,
        };
    }

    fn deinit(self: ScratchCards) void {
        for (self.lines) |line|
            self.allocator.free(line);
        self.allocator.free(self.lines);
    }

    fn getPointsTotal(self: ScratchCards) u32 {
        var points: u32 = 0;

        for (self.lines) |line|
            points += getCardPoints(line);

        return points;
    }
};

fn getCardPoints(line: []const u8) u32 {
    var it = std.mem.splitScalar(u8, line, '|');

    const winners: Numbers = getWinners(it.next().?);
    const numbers: Numbers = getNumbers(it.next().?);

    const intersection = winners.intersectWith(numbers);
    var count = intersection.count();
    if (count != 0) {
        var result: u32 = 1;
        while (count > 1) : (count -= 1)
            result *= 2;
        return result;
    }
    return 0;
}

fn getWinners(slice: []const u8) Numbers {
    var it = std.mem.splitScalar(u8, slice, ':');
    _ = it.next(); // discard

    return getNumbers(it.next().?);
}

fn getNumbers(slice: []const u8) Numbers {
    var bitset = Numbers.initEmpty();
    var it = std.mem.tokenizeScalar(u8, slice, ' ');
    while (it.next()) |digits|
        bitset.set(std.fmt.parseInt(usize, digits, 10) catch unreachable);
    return bitset;
}
