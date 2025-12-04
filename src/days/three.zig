const std = @import("std");
const root = @import("AOC2025");
const inputs = @import("input").Input;
const solutions = root.Solutions;

const examplePattern1 =
    \\987654321111111
    \\811111111111119
    \\234234234234278
    \\818181911112111
;
const examplePattern2 = "123456789\n987654321"; // Part 1: 89+98=187, Part 2: 123456789+987654321=1111111110
const finalPattern = inputs.three.data();

fn Battery(comptime bank_size: usize) type {
    return struct {
        const Self = @This();

        input: []const u8,

        pub fn init(string: []const u8) !Self {
            if (string.len != bank_size) {
                return error.InvalidLength;
            }
            return Self{ .input = string };
        }

        inline fn invidiualJoltages(self: *const Self, comptime activeCellsCount: usize) []u8 {
            comptime {
                if (activeCellsCount > bank_size) {
                    @compileError("activeCellsCount cannot exceed bank_size");
                }
                if (activeCellsCount == 0) {
                    @compileError("activeCellsCount must be at least 1");
                }
            }

            var bestValues: [activeCellsCount]u8 = @splat(0);
            var bestIndices: [activeCellsCount]usize = @splat(0);

            for (self.input, 0..) |character, currentIndex| {
                const digit: u8 = character - '0';

                inline for (0..activeCellsCount) |selectionIndex| {
                    const digitsNeededAfter = activeCellsCount - selectionIndex - 1;
                    const maximumIndexForSlot = bank_size - 1 - digitsNeededAfter;

                    if (currentIndex <= maximumIndexForSlot) {
                        const minimumIndex = if (selectionIndex == 0) 0 else bestIndices[selectionIndex - 1] + 1;

                        if (currentIndex >= minimumIndex and digit > bestValues[selectionIndex]) {
                            bestValues[selectionIndex] = digit;
                            bestIndices[selectionIndex] = currentIndex;
                            inline for (selectionIndex + 1..activeCellsCount) |resetIndex| {
                                bestValues[resetIndex] = 0;
                                bestIndices[resetIndex] = 0;
                            }
                        }
                    }
                }
            }

            return bestValues[0..activeCellsCount];
        }

        pub fn totalJoltage(self: *const Self, comptime activeCellsCount: usize) u64 {
            const joltages = self.invidiualJoltages(activeCellsCount);

            var result: u64 = 0;
            inline for (0..activeCellsCount) |i| {
                const joltage = @as(u64, joltages[i]);
                result = result * 10 + joltage;
            }
            return result;
        }
    };
}

fn BatteryPack(comptime bank_size: usize) type {
    return struct {
        const Self = @This();
        const BatteryType = Battery(bank_size);

        input: []const u8,

        pub fn init(string: []const u8) !Self {
            return Self{ .input = string };
        }

        pub fn totalJoltage(self: *const Self, comptime activeCellsCount: usize) !u64 {
            var total: u64 = 0;
            var tokenizer = std.mem.tokenizeSequence(u8, self.input, "\n");
            while (tokenizer.next()) |line| {
                var battery = try BatteryType.init(line);
                total += battery.totalJoltage(activeCellsCount);
            }
            return total;
        }
    };
}

test "Example Pattern Part 1" {
    const batteryPack = try BatteryPack(15).init(examplePattern1);
    try std.testing.expectEqual(357, try batteryPack.totalJoltage(2));
}

test "Minimal Example Pattern Part 1" {
    const batteryPack = try BatteryPack(9).init(examplePattern2);
    try std.testing.expectEqual(187, try batteryPack.totalJoltage(2));
}

pub fn Solution_Part_One() !u64 {
    const batteryPack = try BatteryPack(100).init(finalPattern);
    return try batteryPack.totalJoltage(2);
}

test "Solution Part One" {
    const result = try Solution_Part_One();
    try std.testing.expectEqual(solutions.DayThree.value(.PartOne), result);
}

test "Example Pattern Part 2" {
    const batteryPack = try BatteryPack(15).init(examplePattern1);
    try std.testing.expectEqual(3121910778619, try batteryPack.totalJoltage(12));
}

test "Minimal Example Pattern Part 2" {
    const batteryPack = try BatteryPack(9).init(examplePattern2);
    try std.testing.expectEqual(1111111110, try batteryPack.totalJoltage(9));
}

pub fn Solution_Part_Two() !u64 {
    const batteryPack = try BatteryPack(100).init(finalPattern);
    return try batteryPack.totalJoltage(12);
}

test "Solution Part Two" {
    const result = try Solution_Part_Two();
    try std.testing.expectEqual(solutions.DayThree.value(.PartTwo), result);
}
