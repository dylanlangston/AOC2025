const std = @import("std");
const root = @import("AOC2025");
const inputs = @import("input").Input;
const solutions = root.Solutions;

const examplePattern1 =
    \\.......S.......
    \\...............
    \\.......^.......
    \\...............
    \\......^.^......
    \\...............
    \\.....^.^.^.....
    \\...............
    \\....^.^...^....
    \\...............
    \\...^.^...^.^...
    \\...............
    \\..^...^.....^..
    \\...............
    \\.^.^.^.^.^...^.
    \\...............
;
const examplePattern2 = ".S.\n...\n.^."; // Part 1: 1, Part 2: 2
const finalPattern = inputs.seven.data();

fn TachyonManifoldSimulator(comptime maxWidth: usize, comptime maxHeight: usize) type {
    return struct {
        const Self = @This();

        splitters: [maxHeight][maxWidth]bool,
        startX: usize,
        height: usize,

        pub fn init(input: []const u8) !Self {
            var self = Self{ .splitters = undefined, .startX = 0, .height = 0 };

            for (0..maxHeight) |y| {
                for (0..maxWidth) |x| {
                    self.splitters[y][x] = false;
                }
            }

            var it = std.mem.tokenizeScalar(u8, input, '\n');
            while (it.next()) |line| : (self.height += 1) {
                if (self.height >= maxHeight) break;
                for (line, 0..) |char, x| {
                    if (x >= maxWidth) break;
                    switch (char) {
                        '^' => self.splitters[self.height][x] = true,
                        'S' => self.startX = x,
                        else => {},
                    }
                }
            }
            return self;
        }

        /// Part 1: Count total splitter hits (beams merge at same positions)
        pub fn countSplits(self: Self) u64 {
            const RowSet = std.bit_set.StaticBitSet(maxWidth);

            var currentBeams = RowSet.initEmpty();
            currentBeams.set(self.startX);

            var total: u64 = 0;
            for (0..self.height) |y| {
                var newBeams = RowSet.initEmpty();

                // Iterate over all active beams
                var beamIter = currentBeams.iterator(.{});
                while (beamIter.next()) |x| {
                    if (self.splitters[y][x]) {
                        // Count hits this round
                        total += 1;

                        // New Beams: Hits shifted left and right
                        if (x > 0) newBeams.set(x - 1);
                        if (x + 1 < maxWidth) newBeams.set(x + 1);
                    } else {
                        // Pass-through: Beams that are NOT hitting a splitter
                        newBeams.set(x);
                    }
                }
                currentBeams = newBeams;
            }
            return total;
        }

        /// Part 2: Count total timelines (each split doubles that timeline)
        pub fn countTimelines(self: Self) u64 {
            // Track number of timelines at each x position
            var timelines: [maxWidth]u64 = undefined;
            for (0..maxWidth) |i| {
                timelines[i] = 0;
            }
            timelines[self.startX] = 1; // Start with 1 timeline

            // Simulate row by row
            for (0..self.height) |y| {
                var newTimelines: [maxWidth]u64 = undefined;
                for (0..maxWidth) |i| {
                    newTimelines[i] = 0;
                }

                // Iterate over all positions with active timelines
                for (0..maxWidth) |x| {
                    const count = timelines[x];
                    if (count == 0) continue;

                    if (self.splitters[y][x]) {
                        // Hit a splitter: each timeline splits into 2
                        // One goes left, one goes right
                        if (x > 0) newTimelines[x - 1] += count;
                        if (x + 1 < maxWidth) newTimelines[x + 1] += count;
                    } else {
                        // Pass-through: timelines continue straight down
                        newTimelines[x] += count;
                    }
                }
                timelines = newTimelines;
            }

            // Sum up all timelines that made it through
            var total: u64 = 0;
            for (0..maxWidth) |x| {
                total += timelines[x];
            }
            return total;
        }
    };
}

test "Example Pattern Part 1" {
    const sim = try TachyonManifoldSimulator(21, 16).init(examplePattern1);
    try std.testing.expectEqual(21, sim.countSplits());
}

test "Minimal Example Pattern Part 1" {
    const sim = try TachyonManifoldSimulator(3, 3).init(examplePattern2);
    try std.testing.expectEqual(1, sim.countSplits());
}

pub fn Solution_Part_One() !u64 {
    const sim = try TachyonManifoldSimulator(141, 141).init(finalPattern);
    return sim.countSplits();
}

test "Solution Part One" {
    const result = try Solution_Part_One();
    try std.testing.expectEqual(solutions.DaySeven.value(.PartOne), result);
}

test "Example Pattern Part 2" {
    const sim = try TachyonManifoldSimulator(21, 16).init(examplePattern1);
    try std.testing.expectEqual(40, sim.countTimelines());
}

test "Minimal Example Pattern Part 2" {
    const sim = try TachyonManifoldSimulator(3, 3).init(examplePattern2);
    try std.testing.expectEqual(2, sim.countTimelines());
}

pub fn Solution_Part_Two() !u64 {
    const sim = try TachyonManifoldSimulator(141, 141).init(finalPattern);
    return sim.countTimelines();
}

test "Solution Part Two" {
    const result = try Solution_Part_Two();
    try std.testing.expectEqual(solutions.DaySeven.value(.PartTwo), result);
}
