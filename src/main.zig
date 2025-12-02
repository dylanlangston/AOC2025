const std = @import("std");
const DayLocator = @import("DayLocator");

// Run all days, or a specific day if a numeric argument is provided
pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();

    if (args.next()) |arg| {
        const day_num = std.fmt.parseInt(u8, arg, 10) catch {
            std.log.err("Invalid argument: '{s}'. Expected a day number (1-25).", .{arg});
            return;
        };
        if (day_num < 1 or day_num > 25) {
            std.log.err("Day number out of range: {d}. Expected a value between 1 and 25.", .{day_num});
            return;
        }
        try DayLocator.runDay(day_num);
    } else {
        try DayLocator.runAllDays();
    }
}

// Run all day's tests
test {
    _ = DayLocator;
}
