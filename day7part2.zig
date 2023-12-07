const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const data = @embedFile("day7.txt");

    const margin = try getTotalWinnings(allocator, data);
    std.debug.print("total winnings: {}\n", .{margin});
}

test "Camel Cards" {
    const allocator = std.testing.allocator;

    const data = @embedFile("day7 sample.txt");

    try std.testing.expectEqual(@as(Currency, 5905), try getTotalWinnings(allocator, data));
}

fn getTotalWinnings(allocator: Allocator, data: []const u8) !Currency {
    var evaluator = try Evaluator.init(allocator);
    defer evaluator.deinit();

    var hands_list = std.ArrayList(Hand).init(allocator);
    defer hands_list.deinit();

    var it = std.mem.splitScalar(u8, data, '\n');
    while (it.next()) |line|
        try hands_list.append(try evaluator.getHand(line));

    const hands = try hands_list.toOwnedSlice();
    defer allocator.free(hands);

    std.sort.insertion(Hand, hands, {}, Hand.compare);

    var total: Currency = 0;
    for (hands, 1..) |hand, i|
        total += hand.bid * @as(Currency, @intCast(i));

    return total;
}

const Rank = u4;
const Ranks = [5]Rank;
const Currency = u32;

const HandType = enum(u3) {
    five_of_a_kind = 6,
    four_of_a_kind = 5,
    full_house = 4,
    three_of_a_kind = 3,
    two_pair = 2,
    one_pair = 1,
    high_card = 0,
};

const Hand = struct {
    type: HandType,
    ranks: Ranks,
    bid: Currency,

    fn compare(_: void, lhs: Hand, rhs: Hand) bool {
        if (@intFromEnum(lhs.type) < @intFromEnum(rhs.type))
            return true;
        if (@intFromEnum(lhs.type) > @intFromEnum(rhs.type))
            return false;
        for (lhs.ranks, rhs.ranks) |lhs_rank, rhs_rank| {
            if (lhs_rank < rhs_rank)
                return true;
            if (lhs_rank > rhs_rank)
                return false;
        }
        return false;
    }
};

const Evaluator = struct {
    allocator: Allocator,
    rank_lookup: std.AutoArrayHashMap(u8, Rank),

    const suit = "J23456789TQKA";

    fn init(allocator: Allocator) !Evaluator {
        var rank_lookup = std.AutoArrayHashMap(u8, Rank).init(allocator);
        for (suit, 1..) |card, rank|
            try rank_lookup.put(card, @intCast(rank));

        return Evaluator{
            .allocator = allocator,
            .rank_lookup = rank_lookup,
        };
    }

    fn deinit(self: *Evaluator) void {
        self.rank_lookup.deinit();
    }

    fn getHand(self: *Evaluator, line: []const u8) !Hand {
        var it = std.mem.splitScalar(u8, line, ' ');
        const cards = try self.evaluateCards(it.next().?);
        const bid = try std.fmt.parseInt(Currency, it.next().?, 10);

        return .{ .bid = bid, .type = cards.hand_type, .ranks = cards.ranks };
    }

    fn evaluateCards(self: *Evaluator, hand: []const u8) !struct { hand_type: HandType, ranks: Ranks } {
        std.debug.assert(hand.len == 5);
        var hand_ranks: Ranks = undefined;
        var counter = std.AutoArrayHashMap(u8, u3).init(self.allocator);
        defer counter.deinit();

        for (hand, 0..) |card, i| {
            const rank = self.rank_lookup.get(card).?;
            hand_ranks[i] = rank;
            const result = try counter.getOrPut(rank);
            if (result.found_existing)
                result.value_ptr.* += 1
            else
                result.value_ptr.* = 1;
        }

        const hand_type = self.getHandType(counter);

        return .{ .hand_type = hand_type, .ranks = hand_ranks };
    }

    fn getHandType(self: *Evaluator, counter: std.AutoArrayHashMap(u8, u3)) HandType {
        const joker_rank = self.rank_lookup.get('J').?;
        const joker_count: u3 = counter.get(joker_rank) orelse 0;
        return switch (counter.count()) {
            1 => .five_of_a_kind,
            2 => {
                var it = counter.iterator();
                return switch (it.next().?.value_ptr.*) {
                    1, 4 => if (joker_count == 0) .four_of_a_kind else .five_of_a_kind,
                    2, 3 => if (joker_count == 0) .full_house else .five_of_a_kind,
                    else => unreachable,
                };
            },
            3 => {
                var it = counter.iterator();
                while (it.next()) |card_count| {
                    return switch (card_count.value_ptr.*) {
                        1 => continue,
                        2 => switch (joker_count) {
                            0 => .two_pair,
                            1 => .full_house,
                            2 => .four_of_a_kind,
                            else => unreachable,
                        },
                        3 => if (joker_count == 0) .three_of_a_kind else .four_of_a_kind,
                        else => unreachable,
                    };
                }
                unreachable;
            },
            4 => if (joker_count == 0) .one_pair else .three_of_a_kind,
            5 => if (joker_count == 0) .high_card else .one_pair,
            else => unreachable,
        };
    }
};
