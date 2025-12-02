const std = @import("std");
const day_one = @import("days/one.zig");

pub fn main() !void {
    const day1_part1 = try day_one.Solution_Part_One();
    std.debug.print("Solution to Day 1, Part 1: {d}\n", .{day1_part1});

    const day1_part2 = try day_one.Solution_Part_Two();
    std.debug.print("Solution to Day 1, Part 2: {d}\n", .{day1_part2});
}

test {
    _ = day_one;
}
