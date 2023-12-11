const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var gardening = Gardening.init(allocator);
    defer gardening.deinit();

    try gardening.load("data/day05.txt");

    std.debug.print("lowest location {}\n", .{gardening.getLowestLocation()});
}

test "If You Give A Seed A Fertilizer" {
    var gardening = Gardening.init(std.testing.allocator);
    defer gardening.deinit();

    try gardening.load("data/day05 sample.txt");

    try std.testing.expectEqual(@as(NumberType, 46), gardening.getLowestLocation());
}

const NumberType = u64;
const NumberList = std.ArrayList(NumberType);

const Range = struct {
    start: NumberType,
    end: NumberType,
};

const Mapping = struct {
    dest_start: NumberType,
    dest_end: NumberType,
    source_start: NumberType,
    source_end: NumberType,
};

const Map = struct {
    allocator: std.mem.Allocator,
    mappings: std.ArrayList(Mapping),

    fn init(allocator: std.mem.Allocator) Map {
        return Map{
            .allocator = allocator,
            .mappings = std.ArrayList(Mapping).init(allocator),
        };
    }

    fn deinit(self: *Map) void {
        self.mappings.deinit();
    }

    // Given an input array of Range - map them to output Range
    // (which may be a greater number of Range items)
    // Caller owns returned slice.
    fn calcRanges(self: *const Map, input: *std.ArrayList(Range)) std.ArrayList(Range) {
        // Input is mutated here and rendered useless elsewhere.
        defer input.deinit();

        // Output will be the same length as input as a minimum.
        var output = std.ArrayList(Range).initCapacity(self.allocator, input.items.len) catch unreachable;

        while (input.items.len != 0) {
            const range = input.pop();
            const start = range.start;
            const end = range.end;
            for (self.mappings.items) |mapping| {
                const overlap_start = @max(start, mapping.source_start);
                const overlap_end = @min(end, mapping.source_end);

                if (overlap_start < overlap_end) {
                    // Overlap, therefore something to map to output.
                    const output_start = mapping.dest_start + overlap_start - mapping.source_start;
                    const output_end = mapping.dest_start + overlap_end - mapping.source_start;
                    output.append(Range{ .start = output_start, .end = output_end }) catch unreachable;

                    // Anything hanging out either side ?
                    // Append it for later pop(). Maybe overlap with another mapping range.
                    if (overlap_start > start)
                        input.append(Range{ .start = start, .end = overlap_start }) catch unreachable;
                    if (end > overlap_end)
                        input.append(Range{ .start = overlap_end, .end = start }) catch unreachable;
                    break;
                }
            } else {
                // No overlap with any range, therefore 1:1 mapping
                output.append(Range{ .start = start, .end = end }) catch unreachable;
            }
        }

        return output;
    }
};

const Gardening = struct {
    allocator: std.mem.Allocator,
    seed_ranges: std.ArrayList(Range),
    seed2soil: Map,
    soil2fertilizer: Map,
    fertilizer2water: Map,
    water2light: Map,
    light2temperature: Map,
    temperature2humidity: Map,
    humidity2location: Map,

    fn init(allocator: std.mem.Allocator) Gardening {
        return Gardening{
            .allocator = allocator,
            .seed_ranges = std.ArrayList(Range).init(allocator),
            .seed2soil = Map.init(allocator),
            .soil2fertilizer = Map.init(allocator),
            .fertilizer2water = Map.init(allocator),
            .water2light = Map.init(allocator),
            .light2temperature = Map.init(allocator),
            .temperature2humidity = Map.init(allocator),
            .humidity2location = Map.init(allocator),
        };
    }

    fn deinit(self: *Gardening) void {
        // self.seed_ranges.deinit();
        self.seed2soil.deinit();
        self.soil2fertilizer.deinit();
        self.fertilizer2water.deinit();
        self.water2light.deinit();
        self.light2temperature.deinit();
        self.temperature2humidity.deinit();
        self.humidity2location.deinit();
    }

    fn load(self: *Gardening, filename: []const u8) !void {
        const f = try std.fs.cwd().openFile(filename, .{});
        defer f.close();

        var buf_reader = std.io.bufferedReader(f.reader());
        var in_stream = buf_reader.reader();

        const State = enum { ready, seed2soil, soil2fertilizer, fertilizer2water, water2light, light2temperature, temperature2humidity, humidity2location };
        var state = State.ready;

        var buf: [1024]u8 = undefined;
        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            if (line.len == 0) {
                state = .ready;
                continue;
            }
            switch (state) {
                .ready => {
                    if (std.mem.startsWith(u8, line, "seeds:")) {
                        self.getSeeds(line);
                    } else if (std.mem.startsWith(u8, line, "seed-to-soil")) {
                        state = .seed2soil;
                    } else if (std.mem.startsWith(u8, line, "soil-to-fertilizer")) {
                        state = .soil2fertilizer;
                    } else if (std.mem.startsWith(u8, line, "fertilizer-to-water")) {
                        state = .fertilizer2water;
                    } else if (std.mem.startsWith(u8, line, "water-to-light")) {
                        state = .water2light;
                    } else if (std.mem.startsWith(u8, line, "light-to-temperature")) {
                        state = .light2temperature;
                    } else if (std.mem.startsWith(u8, line, "temperature-to-humidity")) {
                        state = .temperature2humidity;
                    } else if (std.mem.startsWith(u8, line, "humidity-to-location")) {
                        state = .humidity2location;
                    } else unreachable;
                    continue;
                },
                .seed2soil => self.appendToMap(&self.seed2soil, line),
                .soil2fertilizer => self.appendToMap(&self.soil2fertilizer, line),
                .fertilizer2water => self.appendToMap(&self.fertilizer2water, line),
                .water2light => self.appendToMap(&self.water2light, line),
                .light2temperature => self.appendToMap(&self.light2temperature, line),
                .temperature2humidity => self.appendToMap(&self.temperature2humidity, line),
                .humidity2location => self.appendToMap(&self.humidity2location, line),
            }
        }
    }

    fn getLowestLocation(self: *Gardening) NumberType {
        var soil_ranges = self.seed2soil.calcRanges(&self.seed_ranges);
        var fertilizer_ranges = self.soil2fertilizer.calcRanges(&soil_ranges);
        var water_ranges = self.fertilizer2water.calcRanges(&fertilizer_ranges);
        var light_ranges = self.water2light.calcRanges(&water_ranges);
        var temperature_ranges = self.light2temperature.calcRanges(&light_ranges);
        var humidity_ranges = self.temperature2humidity.calcRanges(&temperature_ranges);
        const location_ranges = self.humidity2location.calcRanges(&humidity_ranges);
        defer location_ranges.deinit();

        var lowest_location: NumberType = std.math.maxInt(NumberType);
        for (location_ranges.items) |range| {
            lowest_location = @min(range.start, lowest_location);
        }
        return lowest_location;
    }

    // Caller owns returned slice memory
    fn getNumbers(self: *Gardening, line: []const u8) []NumberType {
        var numbers = NumberList.init(self.allocator);
        var it = std.mem.splitScalar(u8, line, ' ');
        while (it.next()) |number_text| {
            const number = std.fmt.parseInt(NumberType, number_text, 10) catch unreachable;
            numbers.append(number) catch unreachable;
        }
        return numbers.toOwnedSlice() catch unreachable;
    }

    fn getSeeds(self: *Gardening, line: []const u8) void {
        var it = std.mem.splitSequence(u8, line, ": ");
        _ = it.next(); // discard
        const seed_ranges = self.getNumbers(it.next().?);
        defer self.allocator.free(seed_ranges);

        for (0..seed_ranges.len / 2) |i| {
            const start = seed_ranges[i * 2];
            const length = seed_ranges[i * 2 + 1];
            const end = start + length;
            self.seed_ranges.append(Range{
                .start = start,
                .end = end,
            }) catch unreachable;
        }
    }

    fn appendToMap(self: *Gardening, map: *Map, line: []const u8) void {
        const numbers = self.getNumbers(line);
        defer self.allocator.free(numbers);

        const length = numbers[2];

        map.mappings.append(Mapping{
            .dest_start = numbers[0],
            .source_start = numbers[1],
            .dest_end = numbers[0] + length,
            .source_end = numbers[1] + length,
        }) catch unreachable;
    }
};
