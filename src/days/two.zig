const std = @import("std");
const root = @import("../root.zig");
const math = std.math;
const fmt = std.fmt;

const examplePattern1 = "11-22,95-115,998-1012,1188511880-1188511890,222220-222224,1698522-1698528,446443-446449,38593856-38593862,565653-565659,824824821-824824827,2121212118-2121212124";
const examplePattern2 = "110-115,1210-1215,10-15"; // Part 1: 1212+11=1223, Part 2: 111+1212+11=1334
const finalPattern = "2157315-2351307,9277418835-9277548385,4316210399-4316270469,5108-10166,872858020-872881548,537939-575851,712-1001,326613-416466,53866-90153,907856-1011878,145-267,806649-874324,6161532344-6161720341,1-19,543444404-543597493,35316486-35418695,20-38,84775309-84908167,197736-309460,112892-187377,336-552,4789179-4964962,726183-793532,595834-656619,1838-3473,3529-5102,48-84,92914229-92940627,65847714-65945664,64090783-64286175,419838-474093,85-113,34939-52753,14849-30381";

// Precomputed powers of 10 up to 10^19
const Pow10 = root.PowersLookup(u64, 10, 20);

// Represents a numeric range [start, end] Ex: 100-200
const Range = struct {
    start: u64,
    end: u64,

    fn Parse(string: []const u8) !Range {
        var iterator = std.mem.splitSequence(u8, string, "-");
        return .{
            .start = try fmt.parseInt(u64, iterator.next() orelse return error.InvalidRange, 10),
            .end = try fmt.parseInt(u64, iterator.next() orelse return error.InvalidRange, 10),
        };
    }
};

// Stores ranges in a Structure of Arrays (SoA) layout using fixed-size stack buffers
fn RangeSet(comptime max_ranges: usize) type {
    return struct {
        const Self = @This();
        starts: [max_ranges]u64,
        ends: [max_ranges]u64,
        len: usize,

        pub fn init(pattern: []const u8) !Self {
            var self = Self{ .starts = undefined, .ends = undefined, .len = 0 };

            var it = std.mem.splitSequence(u8, pattern, ",");
            while (it.next()) |range_str| {
                if (self.len >= max_ranges) return error.BufferTooSmall;
                const r = try Range.Parse(range_str);
                self.starts[self.len] = r.start;
                self.ends[self.len] = r.end;
                self.len += 1;
            }

            self.sortAndMerge();
            return self;
        }

        // Binary search to check if value is within any range
        pub fn contains(self: Self, value: u64) bool {
            var left: usize = 0;
            var right: usize = self.len;
            while (left < right) {
                const middle = left + (right - left) / 2;
                if (self.starts[middle] <= value) {
                    left = middle + 1;
                } else {
                    right = middle;
                }
            }
            return left > 0 and value <= self.ends[left - 1];
        }

        pub fn getMaxEnd(self: Self) u64 {
            return if (self.len == 0) 0 else self.ends[self.len - 1];
        }

        fn sortAndMerge(self: *Self) void {
            const Context = struct {
                starts: *[max_ranges]u64,
                ends: *[max_ranges]u64,
                pub fn swap(context: @This(), a: usize, b: usize) void {
                    std.mem.swap(u64, &context.starts[a], &context.starts[b]);
                    std.mem.swap(u64, &context.ends[a], &context.ends[b]);
                }
                pub fn lessThan(context: @This(), a: usize, b: usize) bool {
                    return context.starts[a] < context.starts[b];
                }
            };
            std.sort.heapContext(0, self.len, Context{ .starts = &self.starts, .ends = &self.ends });

            // Merge overlapping ranges
            var writeIndex: usize = 0;
            for (1..self.len) |readIndex| {
                if (self.starts[readIndex] <= self.ends[writeIndex] + 1) {
                    self.ends[writeIndex] = @max(self.ends[writeIndex], self.ends[readIndex]);
                } else {
                    writeIndex += 1;
                    self.starts[writeIndex] = self.starts[readIndex];
                    self.ends[writeIndex] = self.ends[readIndex];
                }
            }
            self.len = writeIndex + 1;
        }
    };
}

fn InvalidIdScanner(comptime Rules: type) type {
    const PairInfo = struct {
        digitCount: u64,
        startNum: u64,
        endNum: u64,
        multiplier: u64,
    };

    // Pair count by repetition rule:
    // - repetitionCount = 2 only: 10 pairs (1-10 digits, each with exactly 2 reps)
    // - repetitionCount >= 2: 46 pairs total (see below for computation)
    //      19 = 1 digit: 19 reps (2 to 20)
    //      9  = 2 digits: 9 reps (2 to 10)
    //      5  = 3 digits: 5 reps (2 to 6)
    //      4  = 4 digits: 4 reps (2 to 5)
    //      3  = 5 digits: 3 reps (2 to 4)
    //      2  = 6 digits: 2 reps (2 to 3)
    //      1  = 7 digits: 1 rep (2)
    //      1  = 8 digits: 1 rep (2)
    //      1  = 9 digits: 1 rep (2)
    //      1  = 10 digits: 1 rep (2)
    //      46 = 19 + 9 + 5 + 4 + 3 + 2 + 1 + 1 + 1 + 1
    const pair_count = comptime block: {
        var count: usize = 0;
        for (1..11) |digitCount| {
            for (2..20 / digitCount + 1) |repetitionCount| {
                if (Rules.shouldIncludeRepetition(repetitionCount)) count += 1;
            }
        }
        break :block count;
    };

    // Precomputes (digitCount, startNum, endNum, multiplier) tuples at comptime.
    // The multiplier converts a base number to its repeated ID: repeated_id = base_number * multiplier
    // For example: digitCount=2, multiplier=101 -> base=12 gives 12*101=1212
    //
    // Mathematical basis: multiplier = 1 + 10^d + 10^(2d) + ... + 10^((r-1)*d)
    // where 'd' is the digit count and 'r' is the repetition count.
    // This is a geometric series: (10^(r*d) - 1) / (10^d - 1)
    // For r=2: multiplier = 10^d + 1 (e.g., d=2 -> 101), so N = x * (10^d + 1)
    //
    // This method of using powers of 10 to manipulate digit blocks is similar to converting
    // repeating decimals to fractions (see https://en.wikipedia.org/wiki/Repeating_decimal).
    const pairs: [pair_count]PairInfo = comptime block: {
        var result: [pair_count]PairInfo = undefined;
        var index: usize = 0;
        for (1..11) |digitCount| {
            for (2..20 / digitCount + 1) |repetitionCount| {
                if (Rules.shouldIncludeRepetition(repetitionCount)) {
                    const base = Pow10.get(digitCount);
                    var multiplier: u64 = 0;
                    var power: u64 = 1;
                    for (0..repetitionCount) |i| {
                        multiplier += power;
                        // Only multiply if we need more iterations
                        if (i + 1 < repetitionCount) power *= base;
                    }
                    result[index] = .{
                        .digitCount = digitCount,
                        .startNum = if (digitCount == 1) 1 else Pow10.get(digitCount - 1),
                        .endNum = Pow10.get(digitCount) - 1,
                        .multiplier = multiplier,
                    };
                    index += 1;
                }
            }
        }
        break :block result;
    };

    // Runtime enumerator state for each precomputed pair
    const PairEnumerator = struct {
        number: u64,
        pairIndex: usize,
        currentId: ?u64,

        fn init(pairIndex: usize, maximumEnd: u64) @This() {
            var self = @This(){
                .number = pairs[pairIndex].startNum,
                .pairIndex = pairIndex,
                .currentId = null,
            };
            self.computeCurrent(maximumEnd);
            return self;
        }

        fn computeCurrent(self: *@This(), maximumEnd: u64) void {
            const pair = pairs[self.pairIndex];
            if (self.number <= pair.endNum) {
                const id = self.number * pair.multiplier;
                self.currentId = if (id <= maximumEnd) id else null;
            } else {
                self.currentId = null;
            }
        }

        fn advance(self: *@This(), maximumEnd: u64) void {
            self.number += 1;
            self.computeCurrent(maximumEnd);
        }
    };

    return struct {
        pub fn sumInvalidIds(rangeSet: anytype) u64 {
            var invalidIdIterator = iterator(rangeSet);
            var sum: u64 = 0;
            while (invalidIdIterator.next()) |id| sum += id;
            return sum;
        }

        pub fn iterator(rangeSet: anytype) InvalidIdIterator(@TypeOf(rangeSet)) {
            return InvalidIdIterator(@TypeOf(rangeSet)).init(rangeSet);
        }

        pub fn InvalidIdIterator(comptime RangeSetType: type) type {
            return struct {
                const Self = @This();
                rangeSet: RangeSetType,
                maximumEnd: u64,
                iterators: [pair_count]PairEnumerator,
                lastId: u64,

                pub fn init(rangeSet: RangeSetType) Self {
                    const maximumEnd = rangeSet.getMaxEnd();
                    var pairEnumerators: [pair_count]PairEnumerator = undefined;
                    for (0..pair_count) |i| {
                        pairEnumerators[i] = PairEnumerator.init(i, maximumEnd);
                    }

                    return .{ .rangeSet = rangeSet, .maximumEnd = maximumEnd, .iterators = pairEnumerators, .lastId = 0 };
                }

                // Returns the next invalid ID in ascending order, or null if none remain.
                // Merges multiple PairEnumerators (one per digit/repetition combo)
                // LastId tracking ensures each unique ID is returned only once (IDs like 1111 appear from both (d=1,r=4) and (d=2,r=2))
                pub fn next(self: *Self) ?u64 {
                    while (true) {
                        var minimumIndex: ?usize = null;
                        var minimumId: u64 = math.maxInt(u64);
                        for (self.iterators, 0..) |pairEnumerator, index| {
                            if (pairEnumerator.currentId) |id| if (id < minimumId) {
                                minimumId = id;
                                minimumIndex = index;
                            };
                        }

                        const selectedIndex = minimumIndex orelse return null;
                        self.iterators[selectedIndex].advance(self.maximumEnd);

                        if (minimumId != self.lastId) {
                            self.lastId = minimumId;
                            if (self.rangeSet.contains(minimumId)) return minimumId;
                        }
                    }
                }
            };
        }
    };
}

const InvalidIdScanner_Rules_ExactlyTwice = InvalidIdScanner(struct {
    pub inline fn shouldIncludeRepetition(comptime repetitionCount: u64) bool {
        return repetitionCount == 2;
    }
});

test "Example Pattern Part 1" {
    const rangeSet = try RangeSet(20).init(examplePattern1);
    try std.testing.expectEqual(1227775554, InvalidIdScanner_Rules_ExactlyTwice.sumInvalidIds(rangeSet));
}

test "Minimal Example Pattern Part 1" {
    const rangeSet = try RangeSet(5).init(examplePattern2);
    try std.testing.expectEqual(1223, InvalidIdScanner_Rules_ExactlyTwice.sumInvalidIds(rangeSet));
}

pub fn Solution_Part_One() !u64 {
    const rangeSet = try RangeSet(50).init(finalPattern);
    return InvalidIdScanner_Rules_ExactlyTwice.sumInvalidIds(rangeSet);
}

test "Solution Part One" {
    const result = try Solution_Part_One();
    try std.testing.expectEqual(29818212493, result);
}

const InvalidIdScanner_Rules_AtLeastTwice = InvalidIdScanner(struct {
    pub inline fn shouldIncludeRepetition(comptime _: u64) bool {
        return true;
    }
});

test "Example Pattern Part 2" {
    const rangeSet = try RangeSet(20).init(examplePattern1);
    try std.testing.expectEqual(4174379265, InvalidIdScanner_Rules_AtLeastTwice.sumInvalidIds(rangeSet));
}

test "Minimal Example Pattern Part 2" {
    const rangeSet = try RangeSet(5).init(examplePattern2);
    try std.testing.expectEqual(1334, InvalidIdScanner_Rules_AtLeastTwice.sumInvalidIds(rangeSet));
}

pub fn Solution_Part_Two() !u64 {
    const rangeSet = try RangeSet(50).init(finalPattern);
    return InvalidIdScanner_Rules_AtLeastTwice.sumInvalidIds(rangeSet);
}

test "Solution Part Two" {
    const result = try Solution_Part_Two();
    try std.testing.expectEqual(37432260594, result);
}
