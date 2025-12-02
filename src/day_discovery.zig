const std = @import("std");

// Lookup table mapping day names to their numerical order (1-12)
const day_order = std.StaticStringMap(u8).initComptime(.{
    .{ "one", 1 },
    .{ "two", 2 },
    .{ "three", 3 },
    .{ "four", 4 },
    .{ "five", 5 },
    .{ "six", 6 },
    .{ "seven", 7 },
    .{ "eight", 8 },
    .{ "nine", 9 },
    .{ "ten", 10 },
    .{ "eleven", 11 },
    .{ "twelve", 12 }, // 2025 only has 12 days, remaining are for completeness
    .{ "thirteen", 13 },
    .{ "fourteen", 14 },
    .{ "fifteen", 15 },
    .{ "sixteen", 16 },
    .{ "seventeen", 17 },
    .{ "eighteen", 18 },
    .{ "nineteen", 19 },
    .{ "twenty", 20 },
    .{ "twenty_one", 21 },
    .{ "twenty_two", 22 },
    .{ "twenty_three", 23 },
    .{ "twenty_four", 24 },
    .{ "twenty_five", 25 },
});

fn getDayOrder(name: []const u8) u8 {
    return day_order.get(name) orelse 255; // Unknown days sort last
}

// Build-time discovery and code generation for AOC daily solutions.
pub fn importDays(comptime days_path: [:0]const u8, comptime module_name: [:0]const u8, b: *std.Build, c: *std.Build.Step.Compile, test_step: ?*std.Build.Step) !*std.Build.Module {
    const a = b.allocator;
    var names = std.ArrayList([]const u8).initCapacity(a, 32) catch unreachable;
    var imports = std.ArrayList([]const u8).initCapacity(a, 32) catch unreachable;

    const dir = try std.fs.cwd().openDir(b.pathJoin(&.{ "src", days_path }), .{ .iterate = true });
    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file or !std.mem.eql(u8, std.fs.path.extension(entry.name), ".zig")) continue;
        const name = entry.name[0 .. entry.name.len - 4];
        try names.append(a, b.dupe(name));
        try imports.append(a, try std.fmt.allocPrint(a, "days/{s}", .{name}));
    }

    const SortCtx = struct {
        n: [][]const u8,
        i: [][]const u8,
        pub fn lessThan(self: @This(), a_idx: usize, b_idx: usize) bool {
            return getDayOrder(self.n[a_idx]) < getDayOrder(self.n[b_idx]);
        }
        pub fn swap(self: @This(), a_idx: usize, b_idx: usize) void {
            std.mem.swap([]const u8, &self.n[a_idx], &self.n[b_idx]);
            std.mem.swap([]const u8, &self.i[a_idx], &self.i[b_idx]);
        }
    };
    std.sort.pdqContext(0, names.items.len, SortCtx{ .n = names.items, .i = imports.items });

    var buf = std.ArrayList(u8).initCapacity(a, 4096) catch unreachable;
    try buf.appendSlice(a,
        \\const std = @import("std");
        \\pub const Solution = union(enum) {
        \\    number: u64, string: []const u8, not_implemented: void,
        \\    pub fn format(self: Solution, writer: anytype) !void {
        \\        switch (self) { .number => |n| try writer.print("{d}", .{n}), .string => |s| try writer.print("{s}", .{s}), .not_implemented => try writer.print("Not implemented", .{}) }
        \\    }
        \\};
        \\inline fn toSolution(v: anytype) Solution {
        \\    const T = @TypeOf(v);
        \\    return if (T == []const u8 or T == [:0]const u8 or @typeInfo(T) == .pointer) .{ .string = v } else .{ .number = @intCast(v) };
        \\}
        \\inline fn solvePart(comptime mod: type, comptime func_name: []const u8) anyerror!Solution {
        \\    if (@hasDecl(mod, func_name)) {
        \\        return toSolution(try @field(mod, func_name)());
        \\    } else {
        \\        return .not_implemented;
        \\    }
        \\}
        \\pub const Days = enum {
        \\
    );
    for (names.items) |n| try buf.appendSlice(a, try std.fmt.allocPrint(a, "    {s},\n", .{n}));
    try buf.appendSlice(a, "    pub fn solvePart1(self: Days) anyerror!Solution { return switch (self) {\n");
    for (names.items, imports.items) |n, imp| try buf.appendSlice(a, try std.fmt.allocPrint(a, "        .{s} => solvePart(@import(\"{s}\"), \"Solution_Part_One\"),\n", .{ n, imp }));
    try buf.appendSlice(a, "    }; }\n    pub fn solvePart2(self: Days) anyerror!Solution { return switch (self) {\n");
    for (names.items, imports.items) |n, imp| try buf.appendSlice(a, try std.fmt.allocPrint(a, "        .{s} => solvePart(@import(\"{s}\"), \"Solution_Part_Two\"),\n", .{ n, imp }));
    try buf.appendSlice(a, "    }; }\n    pub fn displayName(self: Days) []const u8 { return switch (self) {\n");
    for (names.items) |n| {
        const day_num = getDayOrder(n);
        try buf.appendSlice(a, try std.fmt.allocPrint(a, "        .{s} => \"{d}\",\n", .{ n, day_num }));
    }
    try buf.appendSlice(a, "    }; }\n    pub fn all() []const Days { return std.enums.values(Days); }\n};\n");
    try buf.appendSlice(a, "fn runDayImpl(day: Days) !void {\n");
    try buf.appendSlice(a, "    std.log.info(\"Solution to Day {s}, Part 1: {f}\", .{ day.displayName(), try day.solvePart1() });\n");
    try buf.appendSlice(a, "    std.log.info(\"Solution to Day {s}, Part 2: {f}\", .{ day.displayName(), try day.solvePart2() });\n}\n");
    try buf.appendSlice(a, "pub fn runAllDays() !void { for (Days.all()) |d| try runDayImpl(d); }\n");
    try buf.appendSlice(a, "pub fn runDay(day_num: u8) !void {\n");
    try buf.appendSlice(a, "    for (Days.all()) |day| {\n");
    try buf.appendSlice(a, "        const display_num = std.fmt.parseInt(u8, day.displayName(), 10) catch continue;\n");
    try buf.appendSlice(a, "        if (display_num == day_num) { try runDayImpl(day); return; }\n");
    try buf.appendSlice(a, "    }\n");
    try buf.appendSlice(a, "    std.log.err(\"Day {d} not found.\", .{day_num});\n}\n");
    try buf.appendSlice(a, "test {\n");
    for (names.items, imports.items) |_, imp| try buf.appendSlice(a, try std.fmt.allocPrint(a, "    _ = @import(\"{s}\");\n", .{imp}));
    try buf.appendSlice(a, "}\n");

    const files_step = b.addWriteFiles();
    const file = files_step.add(module_name ++ ".zig", buf.items);
    const module = b.addModule(module_name, .{ .root_source_file = file.dupe(b), .target = c.root_module.resolved_target });
    const root_mod = b.createModule(.{ .root_source_file = b.path("src/root.zig") });

    for (names.items) |n| {
        const day_mod = b.createModule(.{
            .root_source_file = b.path(try std.fmt.allocPrint(a, "src/days/{s}.zig", .{n})),
            .imports = &.{.{ .name = "AOC2025", .module = root_mod }},
            .target = c.root_module.resolved_target,
        });
        module.addImport(try std.fmt.allocPrint(a, "days/{s}", .{n}), day_mod);

        if (test_step) |ts| {
            const day_tests = b.addTest(.{ .root_module = day_mod });
            ts.dependOn(&b.addRunArtifact(day_tests).step);
        }
    }
    c.root_module.addImport(module_name, module);
    return module;
}
