const std = @import("std");

const Numbers = std.bit_set.ArrayBitSet(usize, 100);
const Card = struct {
    number: u32,
    matches: Numbers,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var scratchcards = try ScratchCards.init(allocator, "data/day4.txt");
    defer scratchcards.deinit();

    const count = scratchcards.getTotalCardsCount();

    std.debug.print("{}\n", .{count});
}

test "Scratchcards" {
    const allocator = std.testing.allocator;

    var scratchcards = try ScratchCards.init(allocator, "data/day4 sample.txt");
    defer scratchcards.deinit();

    try std.testing.expectEqual(@as(usize, 30), scratchcards.getTotalCardsCount());
}

const ScratchCards = struct {
    allocator: std.mem.Allocator,
    card_lookup: std.AutoArrayHashMap(u32, Numbers),

    fn init(allocator: std.mem.Allocator, filename: []const u8) !ScratchCards {
        var scratchcards = ScratchCards{
            .allocator = allocator,
            .card_lookup = std.AutoArrayHashMap(u32, Numbers).init(allocator),
        };

        const f = try std.fs.cwd().openFile(filename, .{});
        defer f.close();

        var buf_reader = std.io.bufferedReader(f.reader());
        var in_stream = buf_reader.reader();

        var lines_array_list = std.ArrayList([]const u8).init(allocator);
        defer lines_array_list.deinit();

        var buf: [1024]u8 = undefined;
        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            try lines_array_list.append(try allocator.dupe(u8, line));
        }

        const lines = try lines_array_list.toOwnedSlice();
        defer {
            for (lines) |line|
                allocator.free(line);
            allocator.free(lines);
        }

        scratchcards.getCards(lines);
        return scratchcards;
    }

    fn deinit(self: *ScratchCards) void {
        self.card_lookup.deinit();
    }

    fn getTotalCardsCount(self: *const ScratchCards) usize {
        // start with all the cards
        const slice: []u32 = self.allocator.dupe(u32, self.card_lookup.keys()) catch unreachable;
        var card_numbers = std.ArrayList(u32).fromOwnedSlice(self.allocator, slice);
        defer card_numbers.deinit();

        var count = card_numbers.items.len;

        while (card_numbers.items.len > 0) {
            var updated_card_numbers = std.ArrayList(u32).init(self.allocator);
            for (card_numbers.items) |number| {
                const bits = self.card_lookup.get(number).?;
                const bits_count = bits.count();
                count += bits_count;
                for (number + 1..number + 1 + bits_count) |number2|
                    updated_card_numbers.append(@intCast(number2)) catch unreachable;
            }
            card_numbers.deinit();
            card_numbers = std.ArrayList(u32).fromOwnedSlice(self.allocator, updated_card_numbers.toOwnedSlice() catch unreachable);
        }
        return count;
    }

    fn getCards(self: *ScratchCards, lines: []const []const u8) void {
        for (lines) |line| {
            const card = getCard(line);
            self.card_lookup.put(card.number, card.matches) catch unreachable;
        }
    }
};

fn getCard(line: []const u8) Card {
    var it1 = std.mem.splitScalar(u8, line, '|');
    var it2 = std.mem.splitScalar(u8, it1.next().?, ':');

    const card_number = getCardNumber(it2.next().?);
    const winners: Numbers = getNumbers(it2.next().?);
    const numbers: Numbers = getNumbers(it1.next().?);

    const matches = winners.intersectWith(numbers);

    return Card{ .number = card_number, .matches = matches };
}

fn getCardNumber(slice: []const u8) u32 {
    var it = std.mem.tokenizeScalar(u8, slice, ' ');
    _ = it.next(); // discard
    return std.fmt.parseInt(u32, it.next().?, 10) catch unreachable;
}

fn getNumbers(slice: []const u8) Numbers {
    var bitset = Numbers.initEmpty();
    var it = std.mem.tokenizeScalar(u8, slice, ' ');
    while (it.next()) |digits|
        bitset.set(std.fmt.parseInt(usize, digits, 10) catch unreachable);
    return bitset;
}
