const std = @import("std");

/// The Solutions enum holds all known solution identifiers and their obfuscated values.
pub const Solutions = enum {
    DayOne,
    DayTwo,
    DayThree,
    DayFour,
    DayFive,
    DaySix,
    DaySeven,
    DayEight,
    DayNine,
    DayTen,
    DayEleven,
    DayTwelve,

    const Part = enum {
        PartOne,
        PartTwo,
    };

    pub fn value(self: Solutions, part: Part) u64 {
        return switch (self) {
            .DayOne => switch (part) {
                .PartOne => obf(59796431895),
                .PartTwo => obf(59796437067),
            },
            .DayTwo => switch (part) {
                .PartOne => obf(47738056872),
                .PartTwo => obf(23002077143),
            },
            .DayThree => switch (part) {
                .PartOne => obf(59796447984),
                .PartTwo => obf(169361977772099),
            },
            .DayFour => switch (part) {
                .PartOne => obf(59796432338),
                .PartTwo => obf(59796423127),
            },
            .DayFive => switch (part) {
                .PartOne => obf(59796431664),
                .PartTwo => obf(343375217021464),
            },
            else => @panic("Solution value not defined for this day."),
        };
    }
};

/// Simple obfuscation for solution values using XOR with a magic constant.
pub inline fn obf(value: u64) u64 {
    const magic: u64 = 0xDEC_25_2025;
    return value ^ magic;
}
pub inline fn obf_signed(value: i128) i128 {
    const magic: i128 = 0xDEC_25_2025;
    return value ^ magic;
}

/// Comptime-generated lookup table for powers of a base value.
/// Avoids exceeding comptime branch limits when using std.math.pow which uses loops internally.
/// Usage: const pow10 = PowersLookup(u64, 10, 20); // 10^0 to 10^19
///        const value = pow10.get(5); // returns 100000
pub fn PowersLookup(comptime T: type, comptime base: T, comptime max_exponent: usize) type {
    return struct {
        const table: [max_exponent]T = init: {
            var array: [max_exponent]T = undefined;
            var value: T = 1;
            for (0..max_exponent) |index| {
                array[index] = value;
                if (index + 1 < max_exponent) value *= base;
            }
            break :init array;
        };

        /// Get base^exp. Returns the value from precomputed table.
        pub inline fn get(exp: usize) T {
            return table[exp];
        }

        /// Get the underlying array for direct indexing
        pub inline fn asArray() *const [max_exponent]T {
            return &table;
        }
    };
}
