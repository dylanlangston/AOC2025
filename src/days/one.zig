const std = @import("std");
const root = @import("AOC2025");
const inputs = @import("input").Input;
const solutions = root.Solutions;

const examplePattern1 =
    \\L68
    \\L30
    \\R48
    \\L5
    \\R60
    \\L55
    \\L1
    \\L99
    \\R14
    \\L82
;
const examplePattern2 = "L50\nR100";
const finalPattern = inputs.one.data();

const Direction = enum {
    Clockwise,
    CounterClockwise,
};

const Rotation = struct {
    direction: Direction,
    turns: u32,

    // Takes in rotation strings like "L30" or "R45" and parses them into Rotation structs
    fn Parse(rotationString: []const u8) !Rotation {
        if (rotationString.len < 2) return error.InvalidFormat;

        const counterClockwiseChar = 'L';
        const clockwiseChar = 'R';
        const directionChar = rotationString[0];
        const turnsSlice = rotationString[1..];
        const turns = std.fmt.parseInt(u32, turnsSlice, 10) catch {
            return error.InvalidNumber;
        };

        if (directionChar == clockwiseChar) {
            return Rotation{ .direction = .Clockwise, .turns = turns };
        } else if (directionChar == counterClockwiseChar) {
            return Rotation{ .direction = .CounterClockwise, .turns = turns };
        } else {
            return error.InvalidDirection;
        }
    }
};

fn ComboLock(comptime Logic: type) type {
    return struct {
        const Self = @This();

        currentPosition: u8,

        // Specific state defined by the ComboLock subtype
        logic: Logic,

        pub fn init(startPosition: u8) !Self {
            if (startPosition == 0) {
                return error.InvalidStartingPositionZero;
            } else if (startPosition > 99) {
                return error.InvalidStartingPositionGreaterThan100;
            }

            return Self{
                .currentPosition = startPosition,
                .logic = Logic{},
            };
        }

        pub fn rotate(self: Self, rotation: Rotation) Self {
            const result = self.logic.calculate(self.currentPosition, rotation);

            return Self{
                .currentPosition = result.newPosition,
                .logic = result.newLogic,
            };
        }

        pub fn rotate_bulk(self: Self, pattern: []const u8) !Self {
            const delimiter = "\n";

            var lock = self;
            var tokenizer = std.mem.tokenizeSequence(u8, pattern, delimiter);

            while (tokenizer.next()) |token| {
                const rotation = try Rotation.Parse(token);
                lock = lock.rotate(rotation);
            }

            return lock;
        }
    };
}

const Logic_Original = struct {
    numberOfTimesLandedOnZero: u16 = 0,

    pub const Result = struct { newPosition: u8, newLogic: Logic_Original };

    pub inline fn calculate(self: Logic_Original, position: u8, rotation: Rotation) Result {
        var currentPosition: u32 = position;
        var numberOfTimesLandedOnZero: u16 = self.numberOfTimesLandedOnZero;

        if (rotation.direction == .Clockwise) {
            currentPosition = (currentPosition + rotation.turns) % 100;
        } else if (rotation.direction == .CounterClockwise) {
            currentPosition = (currentPosition + 100 - (rotation.turns % 100)) % 100;
        } else {
            @panic("Invalid rotation direction");
        }

        if (currentPosition == 0) {
            numberOfTimesLandedOnZero += 1;
        }

        return Result{
            .newPosition = @intCast(currentPosition),
            .newLogic = .{
                .numberOfTimesLandedOnZero = numberOfTimesLandedOnZero,
            },
        };
    }
};

const ComboLock_Method_One = ComboLock(Logic_Original);

test "Example Pattern Part 1" {
    var lock = try ComboLock_Method_One.init(50);
    lock = try lock.rotate_bulk(examplePattern1);
    const password = lock.logic.numberOfTimesLandedOnZero;
    try std.testing.expectEqual(
        3,
        password,
    );
}

test "Minimal Example Pattern Part 1" {
    var lock = try ComboLock_Method_One.init(50);
    lock = try lock.rotate_bulk(examplePattern2);
    const password = lock.logic.numberOfTimesLandedOnZero;
    try std.testing.expectEqual(
        2,
        password,
    );
}

pub fn Solution_Part_One() !u16 {
    var lock = try ComboLock_Method_One.init(50);
    lock = try lock.rotate_bulk(finalPattern);
    const password = lock.logic.numberOfTimesLandedOnZero;
    return password;
}

test "Solution Part One" {
    const result = try Solution_Part_One();
    try std.testing.expectEqual(
        solutions.DayOne.value(.PartOne),
        result,
    );
}

const Logic_0x434C49434B = struct {
    numberOfTimesPassedZero: u32 = 0,

    pub const Result = struct { newPosition: u8, newLogic: Logic_0x434C49434B };

    pub inline fn calculate(self: Logic_0x434C49434B, position: u8, rotation: Rotation) Result {
        var currentPosition: u32 = position;
        var numberOfTimesPassedZero: u32 = self.numberOfTimesPassedZero;

        if (rotation.direction == .Clockwise) {
            const total_distance = @as(u64, currentPosition) + rotation.turns;
            numberOfTimesPassedZero += @intCast(total_distance / 100);
            currentPosition = @intCast(total_distance % 100);
        } else if (rotation.direction == .CounterClockwise) {
            const inverted_position = (100 - currentPosition) % 100;
            const total_distance = @as(u64, inverted_position) + rotation.turns;
            numberOfTimesPassedZero += @intCast(total_distance / 100);
            currentPosition = (currentPosition + 100 - (rotation.turns % 100)) % 100;
        } else {
            @panic("Invalid rotation direction");
        }

        return Result{
            .newPosition = @intCast(currentPosition),
            .newLogic = .{
                .numberOfTimesPassedZero = numberOfTimesPassedZero,
            },
        };
    }
};

const ComboLock_Method_0x434C49434B = ComboLock(Logic_0x434C49434B);

test "Example Pattern Part 2" {
    var lock = try ComboLock_Method_0x434C49434B.init(50);
    lock = try lock.rotate_bulk(examplePattern1);
    const password = lock.logic.numberOfTimesPassedZero;
    try std.testing.expectEqual(
        6,
        password,
    );
}

test "Minimal Example Pattern Part 2" {
    var lock = try ComboLock_Method_0x434C49434B.init(50);
    lock = try lock.rotate_bulk(examplePattern2);
    const password = lock.logic.numberOfTimesPassedZero;
    try std.testing.expectEqual(
        2,
        password,
    );
}

pub fn Solution_Part_Two() !u32 {
    var lock = try ComboLock_Method_0x434C49434B.init(50);
    lock = try lock.rotate_bulk(finalPattern);
    const password = lock.logic.numberOfTimesPassedZero;
    return password;
}

test "Solution Part Two" {
    const result = try Solution_Part_Two();
    try std.testing.expectEqual(
        solutions.DayOne.value(.PartTwo),
        result,
    );
}
