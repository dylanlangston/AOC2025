const std = @import("std");
const root = @import("AOC2025");
const inputs = @import("input").Input;
const fmt = std.fmt;
const mem = std.mem;
const solutions = root.Solutions;

const examplePattern1 =
    \\3-5
    \\10-14
    \\16-20
    \\12-18
    \\
    \\1
    \\5
    \\8
    \\11
    \\17
    \\32
;
const examplePattern2 = "1-3\n\n2\n5"; // Range 1-3, IDs: 2 (in range), 5 (out). Part 1: 1, Part 2: 3
const finalPattern = inputs.five.data();

// Represents a range of fresh ingredients
const FreshIngredientRange = struct {
    min: u64,
    max: u64,

    fn init(string: []const u8) !FreshIngredientRange {
        var iterator = mem.splitSequence(u8, string, "-");
        return .{
            .min = try fmt.parseInt(u64, iterator.next() orelse return error.InvalidRange, 10),
            .max = try fmt.parseInt(u64, iterator.next() orelse return error.InvalidRange, 10),
        };
    }
};

// More or less the same as Day 2
// Stores ranges in a Structure of Arrays (SoA) layout using fixed-size stack buffers
fn FreshIngredientRangeSet(comptime max_ranges: usize) type {
    return struct {
        const Self = @This();
        starts: [max_ranges]u64,
        ends: [max_ranges]u64,
        len: usize,

        pub fn init(iterator: *mem.SplitIterator(u8, .sequence)) !Self {
            var self = Self{ .starts = undefined, .ends = undefined, .len = 0 };

            while (iterator.peek()) |range_str| {
                if (self.len >= max_ranges) return error.BufferTooSmall;
                if (mem.count(u8, range_str, "-") != 1) {
                    _ = iterator.next();
                    break;
                } else {
                    _ = iterator.next();
                }
                const r = try FreshIngredientRange.init(range_str);
                self.starts[self.len] = r.min;
                self.ends[self.len] = r.max;
                self.len += 1;
            }

            self.sortAndMerge();
            return self;
        }

        pub fn asRanges(self: Self) []FreshIngredientRange {
            var ranges: [max_ranges]FreshIngredientRange = undefined;
            for (0..self.len) |i| {
                ranges[i] = FreshIngredientRange{ .min = self.starts[i], .max = self.ends[i] };
            }
            return ranges[0..self.len];
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

        fn sortAndMerge(self: *Self) void {
            const Context = struct {
                starts: *[max_ranges]u64,
                ends: *[max_ranges]u64,
                pub fn swap(context: @This(), a: usize, b: usize) void {
                    mem.swap(u64, &context.starts[a], &context.starts[b]);
                    mem.swap(u64, &context.ends[a], &context.ends[b]);
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

fn FreshIdIterator(comptime max_ranges: usize) type {
    return struct {
        const Self = @This();

        range: FreshIngredientRangeSet(max_ranges),
        iterator: mem.SplitIterator(u8, .sequence),

        pub fn init(range: FreshIngredientRangeSet(max_ranges), iterator: mem.SplitIterator(u8, .sequence)) Self {
            return Self{
                .range = range,
                .iterator = iterator,
            };
        }

        pub fn next(self: *Self) !?u64 {
            while (self.iterator.next()) |id_str| {
                const id = try fmt.parseInt(u64, id_str, 10);
                if (self.range.contains(id)) {
                    return id;
                }
            }
            return null;
        }

        pub fn reset(self: *Self) void {
            self.iterator.reset();
        }
    };
}

fn IngredientsDatabase(comptime max_ranges: usize) type {
    return struct {
        const Self = @This();
        freshIngredients: FreshIdIterator(max_ranges),

        pub fn init(pattern: []const u8) !Self {
            var mainIterator = mem.splitSequence(u8, pattern, "\n\n");
            var rangeIterator = mem.splitSequence(u8, mainIterator.next() orelse return error.InvalidPattern, "\n");
            const freshIdIterator = mem.splitSequence(u8, mainIterator.next() orelse return error.InvalidPattern, "\n");

            return Self{
                .freshIngredients = FreshIdIterator(max_ranges).init(
                    try FreshIngredientRangeSet(max_ranges).init(&rangeIterator),
                    freshIdIterator,
                ),
            };
        }

        pub fn totalFreshIngredients(self: *Self) !u64 {
            const ranges = self.freshIngredients.range.asRanges();
            var total: u64 = 0;
            for (ranges) |range| {
                total += range.max - range.min + 1;
            }
            return total;
        }

        pub fn totalAvailableFreshIngredients(self: *Self) !u64 {
            var count: u64 = 0;
            while (try self.freshIngredients.next()) |_| {
                count += 1;
            }
            self.freshIngredients.reset();
            return count;
        }
    };
}

test "Example Pattern Part 1" {
    var db = try IngredientsDatabase(5).init(examplePattern1);
    try std.testing.expectEqual(3, try db.totalAvailableFreshIngredients());
}

test "Minimal Example Pattern Part 1" {
    var db = try IngredientsDatabase(5).init(examplePattern2);
    try std.testing.expectEqual(1, try db.totalAvailableFreshIngredients());
}

pub fn Solution_Part_One() !u64 {
    var db = try IngredientsDatabase(175).init(finalPattern);
    return try db.totalAvailableFreshIngredients();
}

test "Solution Part One" {
    const result = try Solution_Part_One();
    try std.testing.expectEqual(solutions.DayFive.value(.PartOne), result);
}

test "Example Pattern Part 2" {
    var db = try IngredientsDatabase(5).init(examplePattern1);
    try std.testing.expectEqual(14, try db.totalFreshIngredients());
}

test "Minimal Example Pattern Part 2" {
    var db = try IngredientsDatabase(5).init(examplePattern2);
    try std.testing.expectEqual(3, try db.totalFreshIngredients());
}

pub fn Solution_Part_Two() !u64 {
    var db = try IngredientsDatabase(175).init(finalPattern);
    return try db.totalFreshIngredients();
}

test "Solution Part Two" {
    const result = try Solution_Part_Two();
    try std.testing.expectEqual(solutions.DayFive.value(.PartTwo), result);
}
