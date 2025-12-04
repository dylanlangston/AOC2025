const std = @import("std");

const Days = enum {
    one,
    two,
    three,
    four,
    five,
    six,
    seven,
    eight,
    nine,
    ten,
    eleven,
    twelve,
    thirteen,
    fourteen,
    fifteen,
    sixteen,
    seventeen,
    eighteen,
    nineteen,
    twenty,
    twenty_one,
    twenty_two,
    twenty_three,
    twenty_four,
    twenty_five,
};

inline fn dayToEmoji(day: Days) []const u8 {
    return switch (day) {
        .one => "🦃🍐🌳",
        .two => "🕊️",
        .three => "🐔",
        .four => "🐦",
        .five => "💍",
        .six => "🪿",
        .seven => "🦢",
        .eight => "👩‍🌾",
        .nine => "💃",
        .ten => "🕺",
        .eleven => "🪈",
        .twelve => "🥁",
        .twenty_five => "🎅",
        else => "",
    };
}

// Build a mapping from string names to enum values at compile time
const daysAsStrings = map: {
    var result = std.EnumArray(Days, []const u8).initUndefined();
    const enumValues = std.enums.values(Days);

    for (enumValues) |day| {
        const name = @tagName(day);
        result.set(day, name);
    }
    break :map result.values;
};

inline fn getDayFromString(name: []const u8) Days {
    inline for (daysAsStrings, 0..) |value, i| {
        if (std.mem.eql(u8, value, name)) {
            return @enumFromInt(i);
        }
    }
    @panic("Day not found!");
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
            return @intFromEnum(getDayFromString(self.n[a_idx])) < @intFromEnum(getDayFromString(self.n[b_idx]));
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
        \\const obf = @import("AOC2025").obf;
        \\pub const Solution = union(enum) {
        \\    number: u64, string: []const u8, not_implemented: void,
        \\    pub fn format(self: Solution, writer: anytype) !void {
        \\        switch (self) { .number => |n| try writer.print("{d} \x1b[2m(obf: {d})\x1b[0m", .{n, obf(n)}), .string => |s| try writer.print("{s}", .{s}), .not_implemented => try writer.print("Not implemented", .{}) }
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
        const day_num = getDayFromString(n);
        try buf.appendSlice(a, try std.fmt.allocPrint(a, "        .{s} => \"{d}\",\n", .{ n, day_num }));
    }
    try buf.appendSlice(a, "    }; }\n    pub fn dayHeader(self: Days) []const u8 { return switch (self) {\n");
    for (names.items) |n| {
        const day = getDayFromString(n);
        const day_num = @intFromEnum(day) + 1;
        const emoji = dayToEmoji(day);
        var repeated_emoji = std.ArrayList(u8).initCapacity(a, emoji.len * day_num) catch unreachable;
        for (0..day_num) |_| {
            try repeated_emoji.appendSlice(a, emoji);
        }
        try buf.appendSlice(a, try std.fmt.allocPrint(a, "        .{s} => \"\\x1b[4mSolution to Day {d}\\x1b[0m {s}\",\n", .{ n, day_num, repeated_emoji.items }));
    }
    try buf.appendSlice(a, "    }; }\n    pub fn all() []const Days { return std.enums.values(Days); }\n};\n");
    try buf.appendSlice(a, "fn runDayImpl(day: Days) !void {\n");
    try buf.appendSlice(a, "    const part1 = try day.solvePart1();\n");
    try buf.appendSlice(a, "    const part2 = try day.solvePart2();\n");
    try buf.appendSlice(a, "    const has_part1 = !std.mem.eql(u8, @tagName(part1), \"not_implemented\");\n");
    try buf.appendSlice(a, "    const has_part2 = !std.mem.eql(u8, @tagName(part2), \"not_implemented\");\n");
    try buf.appendSlice(a, "    if (!has_part1 and !has_part2) return;\n");
    try buf.appendSlice(a, "    std.log.info(\"{s}\", .{day.dayHeader()});\n");
    try buf.appendSlice(a, "    if (has_part1) std.log.info(\"         Part 1: {f}\", .{part1});\n");
    try buf.appendSlice(a, "    if (has_part2) std.log.info(\"         Part 2: {f}\", .{part2});\n}\n");
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

    var day_modules = std.StringHashMap(*std.Build.Module).init(a);
    const build_imports = b.modules.values();
    const build_import_names = b.modules.keys();

    for (names.items) |n| {
        const day_mod = b.createModule(.{
            .root_source_file = b.path(try std.fmt.allocPrint(a, "src/days/{s}.zig", .{n})),
            .target = c.root_module.resolved_target,
        });
        for (build_imports, build_import_names) |mod, name| {
            day_mod.addImport(name, mod);
        }
        try day_modules.put(try std.fmt.allocPrint(a, "days/{s}", .{n}), day_mod);

        if (test_step) |ts| {
            const day_tests = b.addTest(.{ .root_module = day_mod });
            ts.dependOn(&b.addRunArtifact(day_tests).step);
        }
    }

    const files_step = b.addWriteFiles();
    const file = files_step.add(module_name ++ ".zig", buf.items);
    const module = b.addModule(module_name, .{ .root_source_file = file.dupe(b), .target = c.root_module.resolved_target });

    for (build_imports, build_import_names) |mod, name| {
        module.addImport(name, mod);
    }

    var day_iter = day_modules.iterator();
    while (day_iter.next()) |entry| {
        module.addImport(entry.key_ptr.*, entry.value_ptr.*);
    }

    c.root_module.addImport(module_name, module);
    return module;
}
