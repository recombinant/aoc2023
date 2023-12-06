const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    const sum = try calculateSum("day1.txt");
    try stdout.print("{}\n", .{sum});
}

test "Trebuchet" {
    try std.testing.expectEqual(@as(u32, 142), try calculateSum("day1 sample1.txt"));
}

fn calculateSum(filename: []const u8) !u16 {
    const f = try std.fs.cwd().openFile(filename, .{});
    defer f.close();

    var buf_reader = std.io.bufferedReader(f.reader());
    var in_stream = buf_reader.reader();

    var sum: u16 = 0;

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const idx1 = std.mem.indexOfAny(u8, line, "0123456789");
        const idx2 = std.mem.lastIndexOfAny(u8, line, "0123456789");
        if (idx1 != null and idx2 != null) {
            const a: u16 = line[idx1.?] - '0';
            const b: u16 = line[idx2.?] - '0';
            sum += a * 10 + b;
        }
    }

    return sum;
}
