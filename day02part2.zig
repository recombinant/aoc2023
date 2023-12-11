const std = @import("std");

const Counts = struct {
    red: u32 = 0,
    blue: u32 = 0,
    green: u32 = 0,
};

pub fn main() !void {
    const sum = try calculateSum("data/day02.txt");
    std.debug.print("sum = {d}\n", .{sum});
}

test "Cube Conundrum" {
    try std.testing.expectEqual(@as(u32, 2286), try calculateSum("data/day02 sample.txt"));
}

fn calculateSum(filename: []const u8) !u32 {
    const f = try std.fs.cwd().openFile(filename, .{});
    defer f.close();

    var buf_reader = std.io.bufferedReader(f.reader());
    var in_stream = buf_reader.reader();

    var sum: u32 = 0;

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var it = std.mem.splitSequence(u8, line, ": ");
        _ = getGameNumber(it.next().?);
        const cube_counts = getCubeCounts(it.next().?);

        const power = cube_counts.red * cube_counts.blue * cube_counts.green;
        sum += power;
    }
    return sum;
}

fn getGameNumber(text: []const u8) u32 {
    const number = text[5..];
    return std.fmt.parseInt(u32, number, 10) catch unreachable;
}

fn getCubeCounts(text: []const u8) Counts {
    var result = Counts{};

    var it_games = std.mem.splitSequence(u8, text, "; ");
    while (it_games.next()) |game| {
        var intermediate = Counts{};
        var it_balls = std.mem.splitSequence(u8, game, ", ");
        while (it_balls.next()) |balls| {
            var it = std.mem.splitScalar(u8, balls, ' ');
            const count = std.fmt.parseInt(u32, it.next().?, 10) catch unreachable;
            const color = it.next().?;
            if (std.mem.eql(u8, color, "red"))
                intermediate.red = count
            else if (std.mem.eql(u8, color, "green"))
                intermediate.green = count
            else if (std.mem.eql(u8, color, "blue"))
                intermediate.blue = count
            else {
                std.debug.print("{s}\n", .{color});
                unreachable;
            }
        }
        result.red = @max(result.red, intermediate.red);
        result.green = @max(result.green, intermediate.green);
        result.blue = @max(result.blue, intermediate.blue);
    }
    return result;
}
