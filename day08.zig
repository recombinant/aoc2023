// AOC 2023 Day 08 Haunted Wasteland
const std = @import("std");

const CountType = u64;
const CountSet = std.AutoArrayHashMap(CountType, void);

pub fn main() !void {
    const data = @embedFile("day08.txt");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var instructions = try Instructions.init(allocator, data);
    defer instructions.deinit();

    const steps = try countSteps(instructions);
    const all_z = try allZ(allocator, instructions);

    std.debug.print("Part 1 - Steps: {d}\n", .{steps});
    std.debug.print("Part 2 - All Z: {d}\n", .{all_z});
}

test "Haunted Wasteland part 1" {
    const data1 = @embedFile("day08 sample1.txt");
    const data2 = @embedFile("day08 sample2.txt");

    const allocator = std.testing.allocator;

    var instructions1 = try Instructions.init(allocator, data1);
    var instructions2 = try Instructions.init(allocator, data2);
    defer instructions1.deinit();
    defer instructions2.deinit();

    const steps1 = try countSteps(instructions1);
    const steps2 = try countSteps(instructions2);

    try std.testing.expectEqual(@as(CountType, 2), steps1);
    try std.testing.expectEqual(@as(CountType, 6), steps2);
}

test "Haunted Wasteland part 2" {
    const data = @embedFile("day08 sample3.txt");

    const allocator = std.testing.allocator;

    var instructions = try Instructions.init(allocator, data);
    defer instructions.deinit();
    const all_z = try allZ(allocator, instructions);

    try std.testing.expectEqual(@as(CountType, 6), all_z);
}

fn countSteps(instructions: Instructions) !CountType {
    var key: []const u8 = "AAA";
    var count: CountType = 0;
    while (true) {
        for (instructions.directions) |turn| {
            count += 1;
            switch (turn) {
                'L' => key = instructions.layout.get(key).?.left,
                'R' => key = instructions.layout.get(key).?.right,
                else => unreachable,
            }

            if (std.mem.eql(u8, key, "ZZZ"))
                return count;
        }
    }
    unreachable;
}

fn allZ(allocator: std.mem.Allocator, instructions: Instructions) !CountType {
    // Only the counts are required, order is irrelevant.
    const final_counts = try getFinalCounts(allocator, instructions);
    defer allocator.free(final_counts);

    // The result is the product of the least common multiples of all the counts.
    var factors = Factors.init(allocator);
    defer factors.deinit();
    for (final_counts) |count|
        try factors.putFactors(count);

    var lcm: CountType = 1;
    const prime_factors = try factors.getFactors();
    for (prime_factors) |factor|
        lcm *= factor;

    return lcm;
}

/// Caller owns returned memory slice.
fn getFinalCounts(allocator: std.mem.Allocator, instructions: Instructions) ![]CountType {
    var final_counts = std.ArrayList(CountType).init(allocator);
    defer final_counts.deinit();

    var keys = std.ArrayList([]const u8).init(allocator);
    defer keys.deinit();
    // Find the starters.
    for (instructions.layout.keys()) |key|
        if (key[2] == 'A')
            try keys.append(key); // starter

    // When a key is a terminator the key can be removed from the loop.
    var remove = std.ArrayList(usize).init(allocator);
    defer remove.deinit();

    // Run until all routes have hit a terminator.
    var count: CountType = 0;
    outer: while (true) {
        for (instructions.directions) |turn| {
            count += 1;
            for (keys.items, 0..) |*key, idx| {
                switch (turn) {
                    'L' => key.* = instructions.layout.get(key.*).?.left,
                    'R' => key.* = instructions.layout.get(key.*).?.right,
                    else => unreachable,
                }
                if (key.*[2] == 'Z')
                    try remove.append(idx); // terminator
            }

            if (remove.items.len != 0) {
                try final_counts.append(count);

                // remove terminators
                std.mem.reverse(usize, remove.items);
                for (remove.items) |idx|
                    _ = keys.swapRemove(idx);

                remove.clearRetainingCapacity();
            }
            if (keys.items.len == 0)
                break :outer; // no keys remaining, all done
        }
    }
    return try final_counts.toOwnedSlice();
}

const Node = struct {
    left: []const u8,
    right: []const u8,
};

const NodeLookup = std.StringArrayHashMap(Node);

/// Takes advantage of Zig's slices. There is no need to copy
/// strings that have been sliced from `data` as `data` remains
/// in scope where `Instructions` is used.
const Instructions = struct {
    allocator: std.mem.Allocator,
    directions: []const u8,
    layout: NodeLookup,

    /// Parse input.
    fn init(allocator: std.mem.Allocator, data: []const u8) !Instructions {
        var line_it = std.mem.splitScalar(u8, data, '\n');

        const directions = line_it.next().?;
        var instructions = Instructions{
            .allocator = allocator,
            .directions = directions,
            .layout = NodeLookup.init(allocator),
        };

        _ = line_it.next().?; // Discard

        while (line_it.next()) |line| {
            const name = line[0..3];
            const left = line[7 .. 7 + 3];
            const right = line[12 .. 12 + 3];
            try instructions.addNode(name, left, right);
        }
        return instructions;
    }

    fn deinit(self: *Instructions) void {
        self.layout.deinit();
    }

    fn addNode(self: *Instructions, name: []const u8, left: []const u8, right: []const u8) !void {
        try self.layout.put(name, Node{ .left = left, .right = right });
    }
};

const Factors = struct {
    allocator: std.mem.Allocator,
    factors_set: CountSet,

    fn init(allocator: std.mem.Allocator) Factors {
        const factors_set = CountSet.init(allocator);
        return Factors{ .allocator = allocator, .factors_set = factors_set };
    }

    fn deinit(self: *Factors) void {
        self.factors_set.deinit();
    }

    fn putFactors(self: *Factors, number: CountType) !void {
        const v: void = comptime {};

        // Brute force.
        for (2..std.math.sqrt(number) + 1) |n| {
            if (number % n == 0) {
                try self.factors_set.put(@intCast(n), v);
                try self.factors_set.put(@intCast(number / n), v);
            }
        }
    }

    /// Return factors. There are no non-prime factors in this task.
    fn getFactors(self: Factors) ![]const CountType {
        return self.factors_set.keys();
    }
};
