const std = @import("std");

// Build-time discovery and embedding for AOC input files.
// Scans src/inputs/ for .txt files and generates an "input" module with embedded file contents.
pub fn embedInputs(b: *std.Build, c: *std.Build.Step.Compile) !*std.Build.Module {
    const a = b.allocator;
    var names = std.ArrayList([]const u8).initCapacity(a, 32) catch unreachable;

    const dir = try std.fs.cwd().openDir(b.pathJoin(&.{ "src", "inputs" }), .{ .iterate = true });
    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file or !std.mem.eql(u8, std.fs.path.extension(entry.name), ".txt")) continue;
        const name = entry.name[0 .. entry.name.len - 4];
        try names.append(a, b.dupe(name));
    }

    var buf = std.ArrayList(u8).initCapacity(a, 4096) catch unreachable;
    try buf.appendSlice(a,
        \\const std = @import("std");
        \\pub const Input = enum {
        \\
    );
    for (names.items) |n| try buf.appendSlice(a, try std.fmt.allocPrint(a, "    {s},\n", .{n}));
    try buf.appendSlice(a,
        \\
        \\    pub fn data(self: Input) []const u8 {
        \\        return std.mem.trim(u8, switch (self) {
        \\
    );
    for (names.items) |n| try buf.appendSlice(a, try std.fmt.allocPrint(a, "            .{s} => @embedFile(\"inputs/{s}\"),\n", .{ n, n }));
    try buf.appendSlice(a,
        \\        }, &std.ascii.whitespace);
        \\    }
        \\};
        \\
    );

    const files_step = b.addWriteFiles();
    const file = files_step.add("input.zig", buf.items);
    const module = b.addModule("input", .{ .root_source_file = file.dupe(b), .target = c.root_module.resolved_target });

    for (names.items) |n| {
        module.addAnonymousImport(try std.fmt.allocPrint(a, "inputs/{s}", .{n}), .{
            .root_source_file = b.path(try std.fmt.allocPrint(a, "src/inputs/{s}.txt", .{n})),
        });
    }

    c.root_module.addImport("input", module);
    return module;
}
