// AOC 2023 Day 11: Cosmic Expansion
const std = @import("std");

pub fn main() !void {
    const data = @embedFile("data/day11.txt");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const answer1 = try getAnswer(allocator, data, false);
    const answer2 = try getAnswer(allocator, data, true);
    std.debug.print("{}\n", .{answer1});
    std.debug.print("{}\n", .{answer2});
}

test "Cosmic Expansion part 1" {
    const data = @embedFile("data/day11 sample.txt");

    const allocator = std.testing.allocator;

    const answer = try getAnswer(allocator, data, false);

    try std.testing.expectEqual(@as(u64, 374), answer);
}

test "Cosmic Expansion part 2" {
    const data = @embedFile("data/day11 sample.txt");

    const allocator = std.testing.allocator;

    const answer = try getAnswer(allocator, data, true);

    try std.testing.expectEqual(@as(u64, 82000210), answer);
}

fn getAnswer(allocator: std.mem.Allocator, data: []const u8, comptime is_part2: bool) !u64 {
    var galaxies = try GalaxyGrid.init(allocator, data, is_part2);
    defer galaxies.deinit();

    return galaxies.getManhattanDistanceSum();
}

const GalaxyGrid = struct {
    allocator: std.mem.Allocator,
    galaxy_grid: [][]bool,
    is_part2: bool,
    size: struct { n_rows: usize, n_cols: usize },

    fn init(allocator: std.mem.Allocator, data: []const u8, is_part2: bool) !GalaxyGrid {
        const galaxy_grid = try GalaxyGrid.getGalaxyGrid(allocator, data);
        return .{
            .allocator = allocator,
            .galaxy_grid = galaxy_grid,
            .is_part2 = is_part2,
            .size = .{ .n_rows = galaxy_grid.len, .n_cols = galaxy_grid[0].len },
        };
    }

    fn deinit(self: *GalaxyGrid) void {
        for (self.galaxy_grid) |array|
            self.allocator.free(array);
        self.allocator.free(self.galaxy_grid);
    }

    // Return 2-dimensional array of bool where `true` represents a galaxy.
    fn getGalaxyGrid(allocator: std.mem.Allocator, data: []const u8) ![][]bool {
        var galaxy_array_list = std.ArrayList([]bool).init(allocator);
        defer galaxy_array_list.deinit();

        var it = std.mem.splitScalar(u8, data, '\n');
        while (it.next()) |line| {
            var galaxy_array = try allocator.alloc(bool, line.len);
            for (line, 0..) |ch, col|
                galaxy_array[col] = (ch == '#');
            try galaxy_array_list.append(galaxy_array);
        }
        return try galaxy_array_list.toOwnedSlice();
    }

    fn getManhattanDistanceSum(self: GalaxyGrid) !u64 {
        const galaxy_locations = try self.getGalaxyLocations();
        const empty_rows = try self.getEmptyRows();
        const empty_cols = try self.getEmptyCols();

        defer self.allocator.free(galaxy_locations);
        defer self.allocator.free(empty_rows);
        defer self.allocator.free(empty_cols);

        const galaxy_count = galaxy_locations.len;
        var sum: u64 = 0;
        for (0..galaxy_count) |idx1|
            for (idx1 + 1..galaxy_count) |idx2| {
                const p1 = galaxy_locations[idx1];
                const p2 = galaxy_locations[idx2];
                sum += self.getManhattanDistance(p1, p2, empty_rows, empty_cols);
            };
        return sum;
    }

    fn getGalaxyLocations(self: GalaxyGrid) ![]Point {
        const n_rows = self.size.n_rows;
        const n_cols = self.size.n_cols;

        var galaxy_locations = std.ArrayList(Point).init(self.allocator);
        defer galaxy_locations.deinit();
        for (0..n_rows) |row|
            for (0..n_cols) |col| {
                if (self.galaxy_grid[row][col])
                    try galaxy_locations.append(Point{ .row = row, .col = col });
            };
        return try galaxy_locations.toOwnedSlice();
    }

    fn getEmptyRows(self: GalaxyGrid) ![]bool {
        const n_rows = self.size.n_rows;
        const n_cols = self.size.n_cols;

        var empty_rows = try self.allocator.alloc(bool, n_rows);
        @memset(empty_rows, false);

        for (0..n_rows) |row| {
            for (0..n_cols) |col| {
                if (self.galaxy_grid[row][col])
                    break;
            } else empty_rows[row] = true;
        }
        return empty_rows;
    }

    fn getEmptyCols(self: GalaxyGrid) ![]bool {
        const n_rows = self.size.n_rows;
        const n_cols = self.size.n_cols;

        var empty_cols = try self.allocator.alloc(bool, n_cols);
        @memset(empty_cols, false);

        for (0..n_cols) |col| {
            for (0..n_rows) |row| {
                if (self.galaxy_grid[row][col])
                    break;
            } else empty_cols[col] = true;
        }
        return empty_cols;
    }

    fn getManhattanDistance(self: GalaxyGrid, p1: Point, p2: Point, empty_rows: []bool, empty_cols: []bool) u64 {
        const row1 = @min(p1.row, p2.row);
        const row2 = @max(p1.row, p2.row);
        const col1 = @min(p1.col, p2.col);
        const col2 = @max(p1.col, p2.col);

        const expansion: u64 = if (self.is_part2) 1_000_000 - 1 else 1;

        var distance: u64 = 0;
        for (row1..row2) |row| {
            distance += 1;
            if (empty_rows[row])
                distance += expansion;
        }
        for (col1..col2) |col| {
            distance += 1;
            if (empty_cols[col])
                distance += expansion;
        }
        return distance;
    }
};

const Point = struct {
    row: usize,
    col: usize,
};
