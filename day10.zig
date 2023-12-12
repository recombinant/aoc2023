// AOC 2023 Day 10: Pipe Maze
const std = @import("std");

pub fn main() !void {
    const data = @embedFile("data/day10.txt");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var grid = try Grid.init(allocator, data);
    defer grid.deinit();

    var result = try grid.countStepsToFarthestPoint();
    defer result.visited_set.deinit();

    // Part 1
    std.debug.print("Steps to farthest point:  {}\n", .{result.step_count});

    // grid.prettify(result.visited_set);
    // grid.printGrid();

    // Part 2
    const answer2 = try grid.countEnclosedTiles(result.visited_set);
    std.debug.print("Number of enclosed tiles: {}\n", .{answer2});
}

test "Pipe Maze part 1" {
    const data1 = @embedFile("data/day10 sample1.txt");
    const data2 = @embedFile("data/day10 sample2.txt");
    const data3 = @embedFile("data/day10 sample3.txt");
    try testPart1(data1, 4);
    try testPart1(data2, 8);
    try testPart1(data3, 8);
}

test "Pipe Maze part 2" {
    const data4 = @embedFile("data/day10 sample4.txt");
    const data5 = @embedFile("data/day10 sample5.txt");
    const data6 = @embedFile("data/day10 sample6.txt");
    try testPart2(data4, 4);
    try testPart2(data5, 8);
    try testPart2(data6, 10);
}

const Grid = struct {
    allocator: std.mem.Allocator,
    tile_grid: [][]PipeTag,
    start: Point,
    size: struct { width: usize, height: usize },

    fn init(allocator: std.mem.Allocator, data: []const u8) !Grid {
        var tile_rows_list = std.ArrayList([]PipeTag).init(allocator);
        defer tile_rows_list.deinit();

        var line_it = std.mem.splitScalar(u8, data, '\n');
        while (line_it.next()) |line| {
            var tile_row = try allocator.alloc(PipeTag, line.len);
            for (line, 0..) |ch, col|
                tile_row[col] = @enumFromInt(ch); // panic? File maybe should be LF not CRLF.
            try tile_rows_list.append(tile_row);
        }
        const tile_grid = try tile_rows_list.toOwnedSlice();

        // Find the start point
        const start: Point = blk: {
            for (tile_grid, 0..) |tile_row, row| {
                for (tile_row, 0..) |tile, col|
                    if (tile == PipeTag.start)
                        break :blk Point{ .row = @truncate(row), .col = @truncate(col) };
            }
            unreachable;
        };

        const grid = Grid{
            .allocator = allocator,
            .tile_grid = tile_grid,
            .start = start,
            .size = .{ .width = tile_grid[0].len, .height = tile_grid.len },
        };
        return grid;
    }

    fn deinit(self: *Grid) void {
        for (self.tile_grid) |tile_row|
            self.allocator.free(tile_row);
        self.allocator.free(self.tile_grid);
    }

    inline fn at(self: Grid, p: Point) PipeTag {
        return self.tile_grid[p.row][p.col];
    }

    inline fn setAt(self: Grid, p: Point, tile: PipeTag) void {
        self.tile_grid[p.row][p.col] = tile;
    }

    /// Every tile in the network has exactly two connections.
    /// Caller owns returned slice memory.
    fn getConnectedPoints(self: Grid, p: Point) ![2]Point {
        const optional_neighbors = try self.getNeighborOffsets(p);
        const neighbors = optional_neighbors orelse unreachable;
        var result: [2]Point = undefined;

        for (neighbors, 0..) |neighbor, i| {
            const p2 = p.add(neighbor);
            result[i] = p2;
        }
        return result;
    }

    /// Get the unit distances to potentially connected neighbors.
    /// There will be either two or none. Start `S` calls this on
    /// each of its neighbors to find the two that connect to
    /// it.
    fn getNeighborOffsets(self: Grid, p: Point) !?[2]Point {
        const I = Point.init;

        if (self.at(p) == PipeTag.start) {
            var result = std.ArrayList(Point).init(self.allocator);
            defer result.deinit();

            // n, e, s & w
            const unit_moves = [4]Point{ I(-1, 0), I(0, 1), I(1, 0), I(0, -1) };
            const n = 1 << 0;
            const e = 1 << 1;
            const s = 1 << 2;
            const w = 1 << 3;
            var bits: u4 = 0;
            for (unit_moves, 0..) |unit_move, direction| {
                // unsigned overflow arithmetic, no negative numbers
                const p2 = p.add(unit_move);
                if (p2.row >= self.size.height or p2.col >= self.size.width)
                    continue;

                // look at the neighbors to check who connects back.
                const optional_neighbors = try self.getNeighborOffsets(p2);
                if (optional_neighbors) |neighbors|
                    for (neighbors) |p3| {
                        if (p.equals(p2.add(p3))) {
                            try result.append(unit_move);
                            bits |= std.math.shl(u4, 1, direction);
                            break;
                        }
                    };
            }

            // Change start `S` to its real PipeTag
            const tile = switch (bits) {
                n | e => PipeTag.north_east,
                n | s => PipeTag.north_south,
                n | w => PipeTag.north_west,
                s | e => PipeTag.south_east,
                e | w => PipeTag.east_west,
                s | w => PipeTag.south_west,
                else => unreachable, // not an AOC map - another pipe points at S
            };
            self.setAt(p, tile);

            var neighbors: [2]Point = undefined;
            std.debug.assert(result.items.len == 2);
            for (result.items, &neighbors) |src, *dest|
                dest.* = src;

            return neighbors;
        } else {
            return switch (self.at(p)) {
                .north_east => [_]Point{ I(-1, 0), I(0, 1) },
                .north_south => [_]Point{ I(-1, 0), I(1, 0) },
                .north_west => [_]Point{ I(-1, 0), I(0, -1) },
                .south_east => [_]Point{ I(1, 0), I(0, 1) },
                .east_west => [_]Point{ I(0, 1), I(0, -1) },
                .south_west => [_]Point{ I(1, 0), I(0, -1) },
                .start, .ground => null, // No connected neighbors.
            };
        }
    }

    // Set of visited points.
    const VisitedSet = std.ArrayHashMap(Point, void, PointContext, true);
    // Priority queue for tile distances.
    const TileDistancePriorityQueue = std.PriorityDequeue(TileDistance, void, tileDistanceCompare);

    /// Caller owns returned VisitedSet memory.
    fn countStepsToFarthestPoint(self: *Grid) !struct { step_count: u16, visited_set: VisitedSet } {
        var visited_set = VisitedSet.init(self.allocator);
        // defer visited_set.deinit();

        var queue = TileDistancePriorityQueue.init(self.allocator, {});
        defer queue.deinit();

        try queue.add(TileDistance{ .point = self.start, .distance = 0 });

        var max_distance: u16 = 0;

        while (queue.count() != 0) {
            const td = queue.removeMin();
            const distance = td.distance + 1;

            const gop = try visited_set.getOrPut(td.point);
            if (gop.found_existing)
                continue;
            gop.value_ptr.* = {};

            const connected_points = try self.getConnectedPoints(td.point);
            for (connected_points) |point| {
                if (visited_set.contains(point))
                    continue;

                try queue.add(TileDistance{ .point = point, .distance = distance });
                if (td.distance > max_distance)
                    max_distance = distance;
            }
        }
        return .{ .step_count = max_distance, .visited_set = visited_set };
    }

    ///  `visited_set` can be found in the return of Grid.countStepsToFarthestPoint()
    fn countEnclosedTiles(self: Grid, visited_set: VisitedSet) !u16 {
        var count: u16 = 0;

        for (0..self.size.height) |row| {
            var crossed = false;
            for (0..self.size.width) |col| {
                const p = Point{ .row = @truncate(row), .col = @truncate(col) };
                if (visited_set.contains(p))
                    switch (self.at(p)) {
                        .north_south, .north_east, .north_west => crossed = !crossed,
                        .east_west, .south_west, .south_east => {},
                        .ground => unreachable, // No ground on network, only pipes.
                        .start => unreachable, // S should have been replaced by the real thing.
                    }
                else
                    count += @intFromBool(crossed);
            }
        }
        return count;
    }

    fn printGrid(self: Grid) void {
        for (self.tile_grid) |tile_row| {
            for (tile_row) |tile|
                std.debug.print("{c}", .{@intFromEnum(tile)});
            std.debug.print("\n", .{});
        }
    }

    /// Remove tiles outside main network. Set them to ground.
    fn prettify(self: *Grid, visited_set: VisitedSet) void {
        for (0..self.size.height) |row| {
            for (0..self.size.width) |col| {
                const p = Point{ .row = @truncate(row), .col = @truncate(col) };
                if (!visited_set.contains(p)) {
                    self.setAt(p, PipeTag.ground);
                }
            }
        }
    }
};

const PipeTag = enum(u8) {
    north_south = '|',
    east_west = '-',
    north_east = 'L',
    north_west = 'J',
    south_west = '7',
    south_east = 'F',
    ground = '.',
    start = 'S',
};

const Point = struct {
    row: u16,
    col: u16,

    fn init(row: i16, col: i16) Point {
        return Point{
            .row = @as(u16, @bitCast(row)),
            .col = @as(u16, @bitCast(col)),
        };
    }

    fn add(self: Point, other: Point) Point {
        return Point{ .row = self.row +% other.row, .col = self.col +% other.col };
    }

    fn equals(self: Point, other: Point) bool {
        return self.row == other.row and self.col == other.col;
    }
};

/// Used by VisitedSet set in countStepsToFarthestPoint()
const PointContext = struct {
    const Self = @This();

    pub fn hash(_: Self, p: Point) u32 {
        return @as(u32, 0x1_0000) * p.row + p.col;
    }

    pub fn eql(_: Self, p1: Point, p2: Point, index: usize) bool {
        _ = index;
        return p1.row == p2.row and p1.col == p2.col;
    }
};

/// Used by TileDistancePriorityQueue in countStepsToFarthestPoint()
const TileDistance = struct {
    point: Point,
    distance: u16,
};

/// Used by TileDistancePriorityQueue in countStepsToFarthestPoint()
/// Only the distance is nneded for the priority queue.
fn tileDistanceCompare(context: void, a: TileDistance, b: TileDistance) std.math.Order {
    _ = context;
    return std.math.order(a.distance, b.distance);
}

test "getNeighbors" {
    const data = @embedFile("data/day10 sample1.txt");
    const allocator = std.testing.allocator;
    var grid = try Grid.init(allocator, data);
    defer grid.deinit();
    const I = Point.init;

    const neighbors = (try grid.getNeighborOffsets(I(3, 3))).?;
    const expected_neigbors: [2]Point = .{ I(-1, 0), I(0, -1) };

    try std.testing.expectEqualSlices(Point, &expected_neigbors, &neighbors);
}

test "getConnectedPoints" {
    const data = @embedFile("data/day10 sample1.txt");
    const allocator = std.testing.allocator;
    var grid = try Grid.init(allocator, data);
    defer grid.deinit();
    const I = Point.init;

    const connected = try grid.getConnectedPoints(I(3, 1));
    const expected_connected: [2]Point = .{ I(2, 1), I(3, 2) };

    try std.testing.expectEqualSlices(Point, &expected_connected, &connected);
}

/// Helper function for test "Pipe Maze part 1"
fn testPart1(data: []const u8, expected: u16) !void {
    const allocator = std.testing.allocator;

    var grid = try Grid.init(allocator, data);
    defer grid.deinit();

    var result = try grid.countStepsToFarthestPoint();
    defer result.visited_set.deinit();

    const answer = result.step_count;

    try std.testing.expectEqual(expected, answer);
}

/// Helper function for test "Pipe Maze part 2"
fn testPart2(data: []const u8, expected: u16) !void {
    const allocator = std.testing.allocator;

    var grid = try Grid.init(allocator, data);
    defer grid.deinit();

    var result = try grid.countStepsToFarthestPoint();
    defer result.visited_set.deinit();

    const answer = try grid.countEnclosedTiles(result.visited_set);

    try std.testing.expectEqual(expected, answer);
}

test "VisitedSet" {
    var visited = Grid.VisitedSet.init(std.testing.allocator);
    defer visited.deinit();

    const p1 = Point{ .row = 0, .col = 0 };
    const p2 = Point{ .row = 1, .col = 0 };

    {
        const gop1: Grid.VisitedSet.GetOrPutResult = try visited.getOrPut(p1);
        try std.testing.expect(!gop1.found_existing);
        gop1.value_ptr.* = {};
    }
    {
        const gop1 = try visited.getOrPut(p1);
        try std.testing.expect(gop1.found_existing);
    }
    {
        const gop2 = try visited.getOrPut(p2);
        try std.testing.expect(!gop2.found_existing);
        gop2.value_ptr.* = {};
    }
    {
        const gop1 = try visited.getOrPut(p1);
        try std.testing.expect(gop1.found_existing);
        const gop2 = try visited.getOrPut(p2);
        try std.testing.expect(gop2.found_existing);
    }
}

test "TileDistancePriorityQueue" {
    var queue = Grid.TileDistancePriorityQueue.init(std.testing.allocator, {});
    defer queue.deinit();

    // Only the distance is required for the queue's compare function.
    const p = Point{ .row = 0, .col = 0 };

    try std.testing.expectEqual(@as(usize, 0), queue.count());

    try queue.add(TileDistance{ .point = p, .distance = 3 });
    try queue.add(TileDistance{ .point = p, .distance = 4 });
    try queue.add(TileDistance{ .point = p, .distance = 1 });
    try queue.add(TileDistance{ .point = p, .distance = 2 });

    try std.testing.expectEqual(@as(usize, 4), queue.count());

    const td1 = queue.removeMin();
    try std.testing.expectEqual(@as(u16, 1), td1.distance);

    const td2 = queue.removeMax();
    try std.testing.expectEqual(@as(u16, 4), td2.distance);

    try std.testing.expectEqual(@as(usize, 2), queue.count());
}
