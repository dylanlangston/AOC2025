const std = @import("std");
const root = @import("AOC2025");
const inputs = @import("input").Input;
const solutions = root.Solutions;

const examplePattern1 =
    \\..@@.@@@@.
    \\@@@.@.@.@@
    \\@@@@@.@.@@
    \\@.@@@@..@.
    \\@@.@@@@.@@
    \\.@@@@@@@.@
    \\.@.@.@.@@@
    \\@.@@@.@@@@
    \\.@@@@@@@@.
    \\@.@.@@@.@.
;

const examplePattern2 = "@.@\n.@.\n@.@"; // Part 1: 4, Part 2: 5
const finalPattern = inputs.four.data();

const PaperRoll = enum(u8) {
    empty = 0,
    roll = 1,

    pub inline fn fromChar(char: u8) PaperRoll {
        return if (char == '@') .roll else .empty;
    }

    pub inline fn asU8(self: PaperRoll) u8 {
        return @intFromEnum(self);
    }
};

fn PaperRollGridCube(comptime size: usize) type {
    return PaperRollGrid(size, size);
}

fn PaperRollGrid(comptime columns: usize, comptime rows: usize) type {
    const paddedLength = columns * 3;
    const LineBuffer = [paddedLength]u8;
    const Vector = @Vector(columns, u8);
    const BoolVector = @Vector(columns, bool);
    const emptyLine: LineBuffer = @splat(0);

    return struct {
        const Self = @This();

        const Position = struct { x: usize, y: usize };

        maxNeighbors: u8,
        gridData: [rows][paddedLength]u8,

        pub fn init(pattern: []const u8) Self {
            return Self.initWithMaxNeighbors(pattern, 4);
        }

        pub fn initWithMaxNeighbors(pattern: []const u8, maxNeighbors: u8) Self {
            var self = Self{
                .maxNeighbors = maxNeighbors,
                .gridData = undefined,
            };
            self.parsePattern(pattern);
            return self;
        }

        // Convert a text line into a padded byte buffer centered at `columns` for safe
        // vector loads when computing left/right neighbor offsets.
        inline fn vectorizeLine(textLine: []const u8, buffer: *LineBuffer) void {
            @memset(buffer, 0);
            for (textLine, 0..) |char, i| {
                buffer[columns + i] = PaperRoll.fromChar(char).asU8();
            }
        }

        // Parse the input pattern and populate gridData.
        inline fn parsePattern(self: *Self, pattern: []const u8) void {
            var lineIterator = std.mem.splitSequence(u8, pattern, "\n");
            var rowIdx: usize = 0;
            while (lineIterator.next()) |line| {
                if (rowIdx < rows) {
                    vectorizeLine(line, &self.gridData[rowIdx]);
                    rowIdx += 1;
                }
            }
            // Zero-fill any remaining rows
            while (rowIdx < rows) : (rowIdx += 1) {
                @memset(&self.gridData[rowIdx], 0);
            }
        }

        // Get a line from gridData, or an empty line if out of bounds.
        inline fn getLine(self: *const Self, row: isize) *const LineBuffer {
            if (row < 0 or row >= rows) {
                return &emptyLine;
            }
            return &self.gridData[@intCast(row)];
        }

        // Vectorized neighbor counting across the 8 surrounding cells. Returns a boolean
        // mask for positions that are rolls and have fewer than `maxNeighbors` neighbors.
        inline fn computeRowMask(self: *const Self, row: usize) BoolVector {
            const rowSigned: isize = @intCast(row);
            const prevLine = self.getLine(rowSigned - 1);
            const currentLine = self.getLine(rowSigned);
            const nextLine = self.getLine(rowSigned + 1);

            const vPrev: Vector = prevLine[columns..][0..columns].*;
            const vCurr: Vector = currentLine[columns..][0..columns].*;
            const vNext: Vector = nextLine[columns..][0..columns].*;
            const vPrevLeft: Vector = prevLine[columns - 1 ..][0..columns].*;
            const vPrevRight: Vector = prevLine[columns + 1 ..][0..columns].*;
            const vCurrLeft: Vector = currentLine[columns - 1 ..][0..columns].*;
            const vCurrRight: Vector = currentLine[columns + 1 ..][0..columns].*;
            const vNextLeft: Vector = nextLine[columns - 1 ..][0..columns].*;
            const vNextRight: Vector = nextLine[columns + 1 ..][0..columns].*;

            const neighborCounts = vPrevLeft + vPrev + vPrevRight + vCurrLeft + vCurrRight + vNextLeft + vNext + vNextRight;
            const isRoll = vCurr == @as(Vector, @splat(PaperRoll.roll.asU8()));
            const fewNeighbors = neighborCounts < @as(Vector, @splat(self.maxNeighbors));
            return @select(bool, isRoll, fewNeighbors, @as(BoolVector, @splat(false)));
        }

        pub fn iterator(self: *Self, comptime multipass: bool) Iterator(multipass) {
            return Iterator(multipass).init(self);
        }

        fn Iterator(comptime multipass: bool) type {
            return struct {
                const Iter = @This();

                grid: *Self,
                row: usize,
                col: usize,
                mask: [columns]bool,
                passHadMatches: if (multipass) bool else void,

                pub fn init(grid: *Self) Iter {
                    return Iter{
                        .grid = grid,
                        .row = 0,
                        .col = 0,
                        .mask = grid.computeRowMask(0),
                        .passHadMatches = if (multipass) false else {},
                    };
                }

                // Advance to the next input row and refresh the neighbor mask.
                inline fn advanceToNextRow(self: *Iter) void {
                    self.row += 1;
                    self.mask = self.grid.computeRowMask(self.row);
                    self.col = 0;
                }

                // Prepare for another pass in multipass mode if any matches were found.
                inline fn startNextPass(self: *Iter) bool {
                    if (!self.passHadMatches) return false;
                    self.row = 0;
                    self.col = 0;
                    self.mask = self.grid.computeRowMask(0);
                    self.passHadMatches = false;
                    return true;
                }

                pub fn next(self: *Iter) ?Position {
                    while (true) {
                        while (self.col < columns) {
                            const col = self.col;
                            self.col += 1;
                            if (self.mask[col]) {
                                if (multipass) {
                                    self.grid.gridData[self.row][columns + col] = PaperRoll.empty.asU8();
                                    self.passHadMatches = true;
                                }
                                return .{ .x = col, .y = self.row };
                            }
                        }

                        if (self.row + 1 < rows) {
                            self.advanceToNextRow();
                            continue;
                        }

                        if (multipass and self.startNextPass()) continue;
                        return null;
                    }
                }
            };
        }

        pub fn countAllAccessible(self: *Self, comptime multiPass: bool) u64 {
            var count: u64 = 0;
            var iter = self.iterator(multiPass);
            while (iter.next()) |_| count += 1;
            return count;
        }
    };
}

test "Example Pattern Part 1" {
    var grid = PaperRollGridCube(10).init(examplePattern1);
    const count = grid.countAllAccessible(false);
    try std.testing.expectEqual(13, count);
}

test "Minimal Example Pattern Part 1" {
    var grid = PaperRollGridCube(3).init(examplePattern2);
    const count = grid.countAllAccessible(false);
    try std.testing.expectEqual(4, count);
}

pub fn Solution_Part_One() !u64 {
    var grid = PaperRollGridCube(139).init(finalPattern);
    return grid.countAllAccessible(false);
}

test "Solution Part One" {
    const result = try Solution_Part_One();
    try std.testing.expectEqual(solutions.DayFour.value(.PartOne), result);
}

test "Example Pattern Part 2" {
    var grid = PaperRollGridCube(10).init(examplePattern1);
    const count = grid.countAllAccessible(true);
    try std.testing.expectEqual(43, count);
}

test "Minimal Example Pattern Part 2" {
    var grid = PaperRollGridCube(3).init(examplePattern2);
    const count = grid.countAllAccessible(true);
    try std.testing.expectEqual(5, count);
}

pub fn Solution_Part_Two() !u64 {
    var grid = PaperRollGridCube(139).init(finalPattern);
    return grid.countAllAccessible(true);
}

test "Solution Part Two" {
    const result = try Solution_Part_Two();
    try std.testing.expectEqual(solutions.DayFour.value(.PartTwo), result);
}
