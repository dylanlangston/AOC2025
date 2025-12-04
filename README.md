# Advent of Code 2025 in Zig

My solutions for [Advent of Code 2025](https://adventofcode.com/2025), written in [Zig](https://ziglang.org/).

## Goals

As an added challenge to myself, I aim to implement each solution with the following constraints:
- **Zero allocation**: Avoid runtime memory allocation (if possible).
- **Utilize Comptime**: Use (and abuse) Zig's comptime capabilities to shift work to compile-time.
- **No external dependencies**: Only the Zig standard library.

## Quick Start

### Dev Container (Recommended)

This project includes a [Dev Container](https://code.visualstudio.com/docs/devcontainers/containers) for a pre-configured development environment. Open the project in VS Code and select **"Reopen in Container"** to get started instantly with Zig and all dependencies ready.

### Prerequisites

- [Zig](https://ziglang.org/download/) (0.16.0-dev.1484+d0ba6642b or later)

### Build & Run

```bash
# Build the project
zig build

# Run all days
zig build run

# Run a specific day (e.g., day 2)
zig build run -- 2

# Run tests
zig build test
```

## Project Structure

```bash
src/
├── main.zig           # CLI entry point
├── root.zig           # Shared utilities (solutions, obfuscation, lookup tables)
├── day_discovery.zig  # Build-time day auto-discovery
├── embed_input.zig    # Build-time input file embedding
├── days/              # Daily solution files
│   ├── one.zig
│   ├── two.zig
│   └── ...
└── inputs/            # Puzzle input files
    ├── one.txt
    ├── two.txt
    └── ...
```

## Architecture

As part of the build we auto-discover and register daily solutions and inputs:
1. **Day Discovery** (`src/day_discovery.zig`): Scans `src/days/` for `.zig` files and generates a `DayLocator` module with all solutions registered automatically.
2. **Input Embedding** (`src/embed_input.zig`): Scans `src/inputs/` for `.txt` files and embeds them directly into the binary, making puzzle inputs available at runtime without external file access.
3. **Solution Interface**: Each day module can export `Solution_Part_One` and `Solution_Part_Two` functions that return a numeric or string result.

## Adding a New Day

1. Create a solution file: `src/days/<day_name>.zig` (e.g., `four.zig`)
2. Create an input file: `src/inputs/<day_name>.txt` (e.g., `four.txt`)
3. Implement your solution:

```zig
const std = @import("std");
const inputs = @import("input").Input;

const input = inputs.<day_name>.data();

pub fn Solution_Part_One() !u64 {
    // Your solution here
    return 0;
}

pub fn Solution_Part_Two() !u64 {
    // Your solution here
    return 0;
}
```

## Testing

Tests are automatically discovered alongside solutions. Add `test` blocks in your day files and they'll be included when running `zig build test`.

### Test Patterns

Each day typically includes multiple types of tests:
1. **Example Tests**: Verify logic against the example inputs provided in the puzzle description
2. **Solution Tests**: Verify the actual solution against the obfuscated expected answer

```zig
// Test with example data from the puzzle description
test "Example Pattern Part 1" {
    const result = try solvePart1(exampleInput);
    try std.testing.expectEqual(42, result);
}

// Verify the actual solution using obfuscated expected values
test "Solution Part One" {
    const result = try Solution_Part_One();
    try std.testing.expectEqual(solutions.DayOne_PartOne.value(), result);
}
```

### Adding Solutions to the Registry

When you solve a new day, add the obfuscated answer to `src/root.zig`:

1. Run `zig build run` to get the obfuscated value from the output:
    ```bash
    info: Solution to Day 4 🐦🐦🐦🐦
    info:          Part 1: 12345 (obf: 54321)
    info:          Part 2: 67890 (obf: 98765)
    ```
2. Add new enum variants (e.g., `DayFour_PartOne`, `DayFour_PartTwo`)
3. Add the obfuscated values in the `value()` switch:
    ```zig
    .DayFour => switch (part) {
        .PartOne => obf(54321),
        .PartTwo => obf(98765),
    },
    ```