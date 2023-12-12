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

    /// Caller owns returned slice memory.
    fn getConnectedPoints(self: Grid, p: Point) ![]Point {
        const move_funcs = try self.getConnectPointOffsets(p);
        defer self.allocator.free(move_funcs);
        const connected_points = try self.allocator.alloc(Point, move_funcs.len);
        for (move_funcs, 0..) |func, i|
            connected_points[i] = func(p);
        std.debug.assert(connected_points.len == 2);
        return connected_points;
    }

    const MoveFn = *const fn (Point) Point;

    /// What are the N, E, S & W point offsets from the current point `p`
    /// for the two connected tiles?
    /// Caller owns returned slice memory.
    fn getConnectPointOffsets(self: Grid, p: Point) ![]MoveFn {
        if (self.at(p) == PipeTag.start) {
            const r = self.size.width - 1;
            const b = self.size.height - 1;
            var directions = std.ArrayList(MoveFn).init(self.allocator);
            defer directions.deinit();

            const n = 1;
            const e = 2;
            const s = 4;
            const w = 8;
            var bits: u4 = 0;
            // Avoid going over the perimeter and ensure target connects in the Start direction.
            if (p.row != 0 and self.okNorth(p)) {
                try directions.append(Point.moveNorth);
                bits |= n;
            }
            if (p.col != r and self.okEast(p)) {
                try directions.append(Point.moveEast);
                bits |= e;
            }
            if (p.row != b and self.okSouth(p)) {
                try directions.append(Point.moveSouth);
                bits |= s;
            }
            if (p.col != 0 and self.okWest(p)) {
                try directions.append(Point.moveWest);
                bits |= w;
            }
            // Start to its real PipeTag
            const tile = switch (bits) {
                n | s => PipeTag.north_south,
                s | w => PipeTag.south_west,
                s | e => PipeTag.south_east,
                e | w => PipeTag.east_west,
                n | e => PipeTag.north_east,
                n | w => PipeTag.north_west,
                else => unreachable, // not an AOC map - another pipe points at S
            };
            self.setAt(p, tile);
            return try directions.toOwnedSlice();
        } else {
            const moves = switch (self.at(p)) {
                .north_south => &[_]MoveFn{ Point.moveNorth, Point.moveSouth },
                .south_west => &[_]MoveFn{ Point.moveSouth, Point.moveWest },
                .south_east => &[_]MoveFn{ Point.moveSouth, Point.moveEast },
                .east_west => &[_]MoveFn{ Point.moveEast, Point.moveWest },
                .north_east => &[_]MoveFn{ Point.moveNorth, Point.moveEast },
                .north_west => &[_]MoveFn{ Point.moveNorth, Point.moveWest },
                .start, .ground => &[0]MoveFn{},
            };
            return try self.allocator.dupe(MoveFn, moves);
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
            defer self.allocator.free(connected_points);

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

    ///  `visited_set` can be found in the return of Grid.countEnclosedTiles()
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
                        .ground => unreachable, // No ground on perimeter.
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

    /// Given a tile, can the tile to the north connect to it?
    /// i.e does the tile to the north have a southerly connection?
    /// Out of bounds must be checked before calling this function.
    fn okNorth(self: Grid, p: Point) bool {
        return switch (self.at(p.moveNorth())) {
            .north_south, .south_west, .south_east, .start => true,
            .east_west, .north_east, .north_west, .ground => false,
        };
    }
    fn okEast(self: Grid, p: Point) bool {
        return switch (self.at(p.moveEast())) {
            .east_west, .north_west, .south_west, .start => true,
            .north_south, .north_east, .south_east, .ground => false,
        };
    }
    fn okSouth(self: Grid, p: Point) bool {
        return switch (self.at(p.moveSouth())) {
            .north_south, .north_east, .north_west, .start => true,
            .east_west, .south_west, .south_east, .ground => false,
        };
    }
    fn okWest(self: Grid, p: Point) bool {
        return switch (self.at(p.moveWest())) {
            .north_east, .east_west, .south_east, .start => true,
            .north_south, .north_west, .south_west, .ground => false,
        };
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

    /// This does not check for out of bounds.
    fn moveNorth(self: Point) Point {
        return Point{ .row = self.row - 1, .col = self.col };
    }
    fn moveEast(self: Point) Point {
        return Point{ .row = self.row, .col = self.col + 1 };
    }
    fn moveSouth(self: Point) Point {
        return Point{ .row = self.row + 1, .col = self.col };
    }
    fn moveWest(self: Point) Point {
        return Point{ .row = self.row, .col = self.col - 1 };
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
