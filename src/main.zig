const std = @import("std");
const DayLocator = @import("DayLocator");

// Run all days, or a specific day if a numeric argument is provided
pub fn main() !void {
    std.log.info("\x1b[1m❄️  Advent of Code 2025 Solutions ❄️\x1b[0m\n", .{});

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
        try DayLocator.runDay(day_num - 1);
    } else {
        try DayLocator.runAllDays();
    }
}

// Run all day's tests
test {
    _ = DayLocator;
}

pub const std_options: std.Options = .{
    .enable_segfault_handler = true,
    .logFn = struct {
        const stdout = std.fs.File.stdout();

        fn log(comptime level: std.log.Level, comptime scope: @EnumLiteral(), comptime format: []const u8, args: anytype) void {
            switch (level) {
                .info => {
                    const buffer_size = 1024;
                    var buffer: [buffer_size]u8 = undefined;
                    _ = stdout.write(std.fmt.bufPrint(&buffer, format ++ "\n", args) catch {
                        std.log.defaultLog(level, scope, format, args);
                        return;
                    }) catch {
                        std.log.defaultLog(level, scope, format, args);
                        return;
                    };
                },
                else => std.log.defaultLog(level, scope, format, args),
            }
        }
    }.log,
};
