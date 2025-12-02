const std = @import("std");

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
