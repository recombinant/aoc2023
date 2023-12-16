// AOC 2023 Day 13 Point of Incidence
const std = @import("std");

pub fn main() !void {
    const data = @embedFile("data/day13.txt");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const answer1 = try getAnswer1(allocator, data);
    const answer2 = try getAnswer2(allocator, data);
    std.debug.print("Part 1 total: {}\n", .{answer1});
    std.debug.print("Part 2 total: {}\n", .{answer2});
}

test "Point of Incidence part 1" {
    const data = @embedFile("data/day13 sample.txt");

    const allocator = std.testing.allocator;

    const answer = try getAnswer1(allocator, data);

    try std.testing.expectEqual(@as(u32, 405), answer);
}

test "Point of Incidence part 2" {
    const data = @embedFile("data/day13 sample.txt");

    const allocator = std.testing.allocator;

    const answer = try getAnswer2(allocator, data);

    try std.testing.expectEqual(@as(u32, 400), answer);
}

/// Calculate the summary for each pattern and return the sum thereof.
fn getAnswer1(allocator: std.mem.Allocator, data: []const u8) !u32 {
    var answer: u32 = 0;
    // blocks of patterns within data
    var pattern_it = std.mem.splitSequence(u8, data, "\n\n");
    while (pattern_it.next()) |pattern_text| {
        var pattern = try Pattern.init(allocator, pattern_text);
        defer pattern.deinit();

        const summary: SummaryResult = pattern.calcSummary(null);

        const v = if (summary.v) |v| v + 1 else 0;
        const h = if (summary.h) |h| (h + 1) * 100 else 0;
        answer += v + h;
    }
    return answer;
}

/// For every pattern found in part 1 toggle every point individually
/// until a new reflection is found.
fn getAnswer2(allocator: std.mem.Allocator, data: []const u8) !u32 {
    var contribution: u32 = 0;
    // blocks of patterns within data
    var pattern_it = std.mem.splitSequence(u8, data, "\n\n");
    while (pattern_it.next()) |pattern_text| {
        var pattern1 = try Pattern.init(allocator, pattern_text);
        defer pattern1.deinit();
        // original summary
        const summary1: SummaryResult = pattern1.calcSummary(null);

        var pattern2 = try pattern1.clone();
        defer pattern2.deinit();
        const n = pattern2.pattern_matrix.n();
        const m = pattern2.pattern_matrix.m();
        outer: for (0..n) |i|
            for (0..m) |j| {
                const c1 = pattern2.pattern_matrix.at(i, j);
                // swap '#' and '.'
                const c2: u8 = switch (c1) {
                    '#' => '.',
                    '.' => '#',
                    else => unreachable,
                };
                pattern2.pattern_matrix.setAt(i, j, c2);
                defer pattern2.pattern_matrix.setAt(i, j, c1);

                const summary2: SummaryResult = pattern2.calcSummary(summary1);
                if (summary2.v == null and summary2.h == null)
                    continue; // not found a reflection yet

                // add 1 as Zig is 0 based and task is 1 based.
                const v = if (summary2.v) |v| v + 1 else 0;
                const h = if (summary2.h) |h| (h + 1) * 100 else 0;
                contribution += v + h;
                break :outer;
            };
    }
    return contribution;
}

const SummaryResult = struct { v: ?u32, h: ?u32 };

const Pattern = struct {
    allocator: std.mem.Allocator,
    pattern_matrix: PatternMatrix(u8),

    fn init(allocator: std.mem.Allocator, line_block: []const u8) !Pattern {
        // lines in the block are concatenated to give the 1D array for the
        // matrix slice
        var line_list = std.ArrayList(u8).init(allocator);
        var line_it = std.mem.splitScalar(u8, line_block, '\n');
        const first_line = line_it.first();
        try line_list.appendSlice(first_line);
        const width = first_line.len;
        var height: usize = 1;
        while (line_it.next()) |line| {
            try line_list.appendSlice(line);
            height += 1;
        }
        const slice = try line_list.toOwnedSlice();
        const pattern_matrix = PatternMatrix(u8){ .slice = slice, .n_rows = height, .m_cols = width };

        return Pattern{ .allocator = allocator, .pattern_matrix = pattern_matrix };
    }
    fn deinit(self: Pattern) void {
        self.allocator.free(self.pattern_matrix.slice);
    }

    fn clone(self: Pattern) !Pattern {
        const pm = self.pattern_matrix;
        const cloned_pm = PatternMatrix(u8){
            .slice = try self.allocator.dupe(u8, pm.slice),
            .n_rows = pm.n_rows,
            .m_cols = pm.m_cols,
        };
        return Pattern{ .allocator = self.allocator, .pattern_matrix = cloned_pm };
    }

    /// `avoid` is only used in part 2. For part 1 .v & .h should be null.
    fn calcSummary(self: *Pattern, avoid: ?SummaryResult) SummaryResult {
        const n = self.pattern_matrix.n();
        const m = self.pattern_matrix.m();

        const is_part2 = (avoid != null);
        const avoid_h = if (is_part2) avoid.?.h else null;
        const avoid_v = if (is_part2) avoid.?.v else null;
        // Part 1 requires horizontal.
        // Part 2 only requires horizontal if part 1 was horizontal.
        // Ditto vertical.
        const h_flag = (!is_part2 or avoid_h != null);
        const v_flag = (!is_part2 or avoid_v != null);

        var horizontal: ?u32 = null;
        if (h_flag)
            for (0..n - 1) |i| {
                if (avoid_h != null and avoid_h.? == i) // part 2 avoid same value as last time
                    continue;
                if (self.isReflected(i)) {
                    horizontal = @truncate(i);
                    break;
                }
            };

        // to avoid writing a second reflection detection algorithm
        // for the other axis, simply transpose the matrix and re-run.
        self.transpose();
        defer self.transpose();

        var vertical: ?u32 = null;
        if (v_flag)
            for (0..m - 1) |j| {
                if (avoid_v != null and avoid_v.? == j) // part 2 avoid same value as last time
                    continue;
                if (self.isReflected(j)) {
                    vertical = @truncate(j);
                    break;
                }
            };

        return .{ .v = vertical, .h = horizontal };
    }

    fn transpose(self: *Pattern) void {
        self.pattern_matrix.transpose();
    }

    /// Given a row, check to see if it is reflected.
    fn isReflected(self: *Pattern, row: usize) bool {
        const pm = self.pattern_matrix;
        const n = pm.n();
        const m = pm.m();
        for (1..n) |offset| {
            const row1 = row + offset;
            const row2 = row + 1 -% offset; // wrap-around subtraction
            if (row1 >= n or row2 >= n)
                continue;
            for (0..m) |col|
                if (pm.at(row1, col) != pm.at(row2, col))
                    return false;
        }
        return true;
    }
};

/// Represent the 2D pattern matrix as a 1D slice.
fn PatternMatrix(comptime T: type) type {
    return struct {
        const Self = @This();

        slice: []T,
        n_rows: usize,
        m_cols: usize,
        transposed: bool = false,

        fn transpose(self: *Self) void {
            self.transposed = !self.transposed;
        }

        fn n(self: Self) usize {
            return if (self.transposed) self.m_cols else self.n_rows;
        }

        fn m(self: Self) usize {
            return if (self.transposed) self.n_rows else self.m_cols;
        }

        fn at(self: Self, i: usize, j: usize) T {
            if (self.transposed) {
                // matrix is transposed, only self.transposed has changed.
                std.debug.assert(i < self.m_cols);
                std.debug.assert(j < self.n_rows);
                return self.slice[i + j * self.m_cols];
            } else {
                std.debug.assert(i < self.n_rows);
                std.debug.assert(j < self.m_cols);
                return self.slice[i * self.m_cols + j];
            }
        }
        fn setAt(self: *Self, i: usize, j: usize, value: T) void {
            if (self.transposed) {
                // matrix is "transposed", only self.transposed has changed.
                std.debug.assert(i < self.m_cols);
                std.debug.assert(j < self.n_rows);
                self.slice[i + j * self.m_cols] = value;
            } else {
                std.debug.assert(i < self.n_rows);
                std.debug.assert(j < self.m_cols);
                self.slice[i * self.m_cols + j] = value;
            }
        }
    };
}
