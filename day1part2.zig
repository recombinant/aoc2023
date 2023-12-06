const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    const sum = try calculateSum("day1.txt");
    try stdout.print("{}\n", .{sum});
}

test "Trebuchet" {
    try std.testing.expectEqual(@as(u32, 281), try calculateSum("day1 sample2.txt"));
}

fn calculateSum(filename: []const u8) !u32 {
    const f = try std.fs.cwd().openFile(filename, .{});
    defer f.close();

    var buf_reader = std.io.bufferedReader(f.reader());
    var in_stream = buf_reader.reader();

    var sum: u32 = 0;

    const digit_words = [_][]const u8{ "one", "two", "three", "four", "five", "six", "seven", "eight", "nine" };
    const digit_letters = "0123456789";

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var digit1: ?u32 = null;
        var digit2: ?u32 = null;
        {
            var idx1: ?usize = null;
            if (std.mem.indexOfAny(u8, line, digit_letters)) |idx| {
                idx1 = idx;
                digit1 = line[idx] - '0';
            }
            for (digit_words, 1..) |word, n| {
                if (std.mem.indexOf(u8, line, word)) |idx| {
                    if (idx1 == null or idx < idx1.?) {
                        idx1 = idx;
                        digit1 = @intCast(n);
                    }
                }
            }
        }
        {
            var idx2: ?usize = null;
            if (std.mem.lastIndexOfAny(u8, line, digit_letters)) |idx| {
                idx2 = idx;
                digit2 = line[idx] - '0';
            }
            for (digit_words, 1..) |word, n| {
                if (std.mem.lastIndexOf(u8, line, word)) |idx| {
                    if (idx2 == null or idx > idx2.?) {
                        idx2 = idx;
                        digit2 = @intCast(n);
                    }
                }
            }
        }
        if (digit1 != null and digit2 != null)
            sum += digit1.? * 10 + digit2.?;
    }
    return sum;
}
