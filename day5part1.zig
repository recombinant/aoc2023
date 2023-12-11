const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var gardening = Gardening.init(allocator);
    defer gardening.deinit();

    try gardening.load("data/day5.txt");

    std.debug.print("lowest location {?}\n", .{gardening.getLowestLocation()});
}

test "If You Give A Seed A Fertilizer" {
    var gardening = Gardening.init(std.testing.allocator);
    defer gardening.deinit();

    try gardening.load("data/day5 sample.txt");

    try std.testing.expectEqual(@as(NumberType, 35), gardening.getLowestLocation().?);
}

const NumberType = u64;
const NumberList = std.ArrayList(NumberType);

const Mapping = struct {
    dest_start: NumberType,
    source_start: NumberType,
    length: NumberType,
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

    fn find(self: *Map, number: NumberType) NumberType {
        for (self.mappings.items) |mapping| {
            if (number >= mapping.source_start and number < mapping.source_start + mapping.length) {
                return mapping.dest_start + number - mapping.source_start;
            }
        }
        return number;
    }
};

const Gardening = struct {
    allocator: std.mem.Allocator,
    seeds: ?NumberList = null,
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
        if (self.seeds) |seeds|
            seeds.deinit();
        self.seed2soil.deinit();
        self.soil2fertilizer.deinit();
        self.fertilizer2water.deinit();
        self.water2light.deinit();
        self.light2temperature.deinit();
        self.temperature2humidity.deinit();
        self.humidity2location.deinit();
    }

    fn getLowestLocation(self: *Gardening) ?NumberType {
        if (self.seeds) |seeds| {
            if (seeds.items.len == 0)
                return null;

            var lowest_location: NumberType = std.math.maxInt(NumberType);

            for (seeds.items) |seed| {
                const soil = self.seed2soil.find(seed);
                const fertilizer = self.soil2fertilizer.find(soil);
                const water = self.fertilizer2water.find(fertilizer);
                const light = self.water2light.find(water);
                const temperature = self.light2temperature.find(light);
                const humidity = self.temperature2humidity.find(temperature);
                const location = self.humidity2location.find(humidity);
                lowest_location = @min(location, lowest_location);
            }
            return lowest_location;
        }
        return null;
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
        self.seeds = NumberList.fromOwnedSlice(self.allocator, self.getNumbers(it.next().?));
    }

    fn appendToMap(self: *Gardening, map: *Map, line: []const u8) void {
        const numbers = self.getNumbers(line);
        defer self.allocator.free(numbers);

        map.mappings.append(Mapping{
            .dest_start = numbers[0],
            .source_start = numbers[1],
            .length = numbers[2],
        }) catch unreachable;
    }
};

test "map/mapping" {
    var gardening = Gardening.init(std.testing.allocator);
    defer gardening.deinit();

    try gardening.load("day5 sample.txt");

    try std.testing.expectEqual(gardening.seed2soil.find(0), @as(NumberType, 0));
    try std.testing.expectEqual(gardening.seed2soil.find(1), @as(NumberType, 1));
    try std.testing.expectEqual(gardening.seed2soil.find(48), @as(NumberType, 48));
    try std.testing.expectEqual(gardening.seed2soil.find(49), @as(NumberType, 49));
    try std.testing.expectEqual(gardening.seed2soil.find(50), @as(NumberType, 52));
    try std.testing.expectEqual(gardening.seed2soil.find(51), @as(NumberType, 53));
    try std.testing.expectEqual(gardening.seed2soil.find(96), @as(NumberType, 98));
    try std.testing.expectEqual(gardening.seed2soil.find(97), @as(NumberType, 99));
    try std.testing.expectEqual(gardening.seed2soil.find(98), @as(NumberType, 50));
    try std.testing.expectEqual(gardening.seed2soil.find(99), @as(NumberType, 51));

    try std.testing.expectEqual(gardening.seed2soil.find(79), @as(NumberType, 81));
    try std.testing.expectEqual(gardening.seed2soil.find(14), @as(NumberType, 14));
    try std.testing.expectEqual(gardening.seed2soil.find(55), @as(NumberType, 57));
    try std.testing.expectEqual(gardening.seed2soil.find(13), @as(NumberType, 13));
}
