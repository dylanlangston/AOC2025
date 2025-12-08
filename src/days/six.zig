const std = @import("std");
const root = @import("AOC2025");
const inputs = @import("input").Input;
const solutions = root.Solutions;

const examplePattern1 =
    \\123 328  51 64 
    \\ 45 64  387 23 
    \\  6 98  215 314
    \\*   +   *   +  
;
const examplePattern2 = "1 2\n3 4\n* +"; // Part 1: 9, Part 2: 37
const finalPattern = inputs.six.data();

fn CephalopodMathToken(comptime maxDigits: usize) type {
    return struct {
        tag: Tag,
        loc: Loc,

        pub const Loc = struct {
            positions: [maxDigits]usize,
            length: usize,
        };

        pub const Tag = enum {
            invalid,
            bof,
            newline,
            number_literal,

            asterisk,
            hyphen,
            plus,
            slash,

            pub fn lexeme(tag: Tag) ?[]const u8 {
                return switch (tag) {
                    .newline => "\n",
                    .asterisk => "*",
                    .hyphen => "-",
                    .plus => "+",
                    .slash => "/",
                    else => null,
                };
            }
        };
    };
}

/// Row-based tokenizer for Part 1
/// Scans the buffer backwards, reading numbers as consecutive horizontal characters
fn RowBasedTokenizer(comptime maxDigits: usize) type {
    return struct {
        const Self = @This();
        const Token = CephalopodMathToken(maxDigits);

        buffer: []const u8,
        index: usize,

        pub fn init(buffer: []const u8) Self {
            return Self{
                .buffer = buffer,
                .index = buffer.len,
            };
        }

        const State = enum {
            start,
            int,
            invalid,
        };

        pub fn peek(self: Self) Token {
            var index = self.index;
            var result: Token = .{
                .loc = .{ .positions = undefined, .length = 0 },
                .tag = undefined,
            };

            if (index == 0) {
                result.tag = .bof;
                result.loc.positions = @splat(0);
                result.loc.length = 0;
                return result;
            }

            state: switch (State.start) {
                .start => switch (self.buffer[index - 1]) {
                    0 => {
                        continue :state .invalid;
                    },

                    // Whitespace characters
                    ' ', '\t', '\r' => {
                        index -= 1;
                        if (index == 0) {
                            result.tag = .bof;
                            result.loc.positions[0] = 0;
                            result.loc.length = 0;
                            return result;
                        }
                        continue :state .start;
                    },

                    '\n' => {
                        result.tag = .newline;
                        index -= 1;
                    },

                    '0'...'9' => {
                        result.tag = .number_literal;
                        result.loc.length = 1;
                        continue :state .int;
                    },

                    '*' => {
                        result.tag = .asterisk;
                        index -= 1;
                    },
                    '-' => {
                        result.tag = .hyphen;
                        index -= 1;
                    },
                    '+' => {
                        result.tag = .plus;
                        index -= 1;
                    },
                    '/' => {
                        result.tag = .slash;
                        index -= 1;
                    },

                    else => continue :state .invalid,
                },

                .int => {
                    index -= 1;
                    if (index == 0) {} else {
                        switch (self.buffer[index - 1]) {
                            '0'...'9' => {
                                result.loc.length += 1;
                                continue :state .int;
                            },
                            else => {},
                        }
                    }
                },

                .invalid => {
                    index -= 1;
                    if (index == 0) {
                        result.tag = .invalid;
                    } else {
                        switch (self.buffer[index - 1]) {
                            '\n' => result.tag = .invalid,
                            else => continue :state .invalid,
                        }
                    }
                },
            }

            result.loc.positions[0] = index;
            if (result.tag != .number_literal) {
                result.loc.length = 1;
            }
            return result;
        }

        pub fn next(self: *Self) Token {
            const token = self.peek();
            self.index = token.loc.positions[0];
            return token;
        }

        pub fn extractNumber(token: Token, expression: []const u8) !i128 {
            const start = token.loc.positions[0];
            const end = start + token.loc.length;
            const number_str = expression[start..end];
            return try std.fmt.parseInt(i128, number_str, 10);
        }
    };
}

/// Column-based tokenizer for Part 2
/// Processes the grid column-by-column from right to left
fn ColumnBasedTokenizer(comptime maxDigits: usize) type {
    return struct {
        const Self = @This();
        const Token = CephalopodMathToken(maxDigits);

        buffer: []const u8,
        row_width: usize,
        num_data_rows: usize,
        current_column: usize,
        pending_operator: ?Token,

        pub fn init(buffer: []const u8) Self {
            var row_width: usize = 0;
            for (buffer, 0..) |c, i| {
                if (c == '\n') {
                    row_width = i + 1;
                    break;
                }
            }
            if (row_width == 0) row_width = buffer.len;

            const total_rows = (buffer.len + row_width - 1) / row_width;
            const num_data_rows = if (total_rows > 1) total_rows - 1 else 0;
            const start_col = if (row_width > 1) row_width - 1 else 1;

            return Self{
                .buffer = buffer,
                .row_width = row_width,
                .num_data_rows = num_data_rows,
                .current_column = start_col,
                .pending_operator = null,
            };
        }

        fn getCharAtColumn(self: Self, column: usize, row: usize) u8 {
            const pos = row * self.row_width + column;
            if (pos >= self.buffer.len) return ' ';
            return self.buffer[pos];
        }

        fn makeOperatorToken(self: Self, tag: Token.Tag, col: usize) Token {
            return Token{
                .tag = tag,
                .loc = .{
                    .positions = blk: {
                        var pos: [maxDigits]usize = @splat(0);
                        pos[0] = self.num_data_rows * self.row_width + col;
                        break :blk pos;
                    },
                    .length = 1,
                },
            };
        }

        fn collectDigits(self: Self, col: usize) Token {
            var result: Token = .{
                .loc = .{ .positions = undefined, .length = 0 },
                .tag = .number_literal,
            };

            var digit_count: usize = 0;
            for (0..self.num_data_rows) |row| {
                const c = self.getCharAtColumn(col, row);
                if (c >= '0' and c <= '9') {
                    result.loc.positions[digit_count] = row * self.row_width + col;
                    digit_count += 1;
                }
            }
            result.loc.length = digit_count;
            return result;
        }

        pub fn next(self: *Self) Token {
            if (self.pending_operator) |op| {
                self.pending_operator = null;
                return op;
            }

            while (self.current_column > 0) {
                const col = self.current_column - 1;
                const operator_char = self.getCharAtColumn(col, self.num_data_rows);

                if (operator_char == '*' or operator_char == '+' or operator_char == '-' or operator_char == '/') {
                    const num_token = self.collectDigits(col);
                    if (num_token.loc.length > 0) {
                        const tag: Token.Tag = switch (operator_char) {
                            '*' => .asterisk,
                            '+' => .plus,
                            '-' => .hyphen,
                            '/' => .slash,
                            else => unreachable,
                        };
                        self.pending_operator = self.makeOperatorToken(tag, col);
                        self.current_column -= 1;
                        return num_token;
                    }
                    const tag: Token.Tag = switch (operator_char) {
                        '*' => .asterisk,
                        '+' => .plus,
                        '-' => .hyphen,
                        '/' => .slash,
                        else => unreachable,
                    };
                    self.current_column -= 1;
                    return self.makeOperatorToken(tag, col);
                }

                if (operator_char == ' ') {
                    const num_token = self.collectDigits(col);
                    if (num_token.loc.length > 0) {
                        self.current_column -= 1;
                        return num_token;
                    }
                    self.current_column -= 1;
                    continue;
                }

                self.current_column -= 1;
            }

            return Token{
                .tag = .bof,
                .loc = .{ .positions = @splat(0), .length = 0 },
            };
        }

        pub fn extractNumber(token: Token, expression: []const u8) !i128 {
            var number_chars: [maxDigits]u8 = undefined;
            for (0..token.loc.length) |i| {
                number_chars[i] = expression[token.loc.positions[i]];
            }
            return try std.fmt.parseInt(i128, number_chars[0..token.loc.length], 10);
        }
    };
}

/// Row-based interpreter logic for Part 1
/// Expects: operators first (bottom row), then numbers row by row
fn RowBasedLogic(comptime maxDigits: usize, comptime maxProblems: usize) type {
    return struct {
        const Tokenizer = RowBasedTokenizer(maxDigits);
        const Token = CephalopodMathToken(maxDigits);

        const Operator = enum {
            add,
            subtract,
            multiply,
            divide,
        };

        pub fn evaluate(expression: []const u8) !i128 {
            var problems: [maxProblems]i128 = @splat(0);
            var operators: [maxProblems]Operator = undefined;

            var tokenizer = Tokenizer.init(expression);

            // First pass: collect operators from bottom row
            for (0..maxProblems) |i| {
                const token = tokenizer.next();
                switch (token.tag) {
                    .asterisk => operators[i] = .multiply,
                    .plus => operators[i] = .add,
                    .hyphen => operators[i] = .subtract,
                    .slash => operators[i] = .divide,
                    .newline => break,
                    .number_literal => return error.FoundNumberBeforeOperator,
                    else => return error.InvalidExpression,
                }
            }

            const peeked = tokenizer.peek();
            switch (peeked.tag) {
                .asterisk, .plus, .hyphen, .slash => return error.FoundOperatorBeforeNumber,
                .bof => return error.NoProblemsInExpression,
                .invalid => return error.InvalidExpression,
                .newline => {
                    _ = tokenizer.next();
                },
                .number_literal => {},
            }

            // Second pass: collect first row of numbers (initializes problems)
            for (0..maxProblems) |i| {
                const token = tokenizer.next();
                switch (token.tag) {
                    .asterisk, .plus, .hyphen, .slash => return error.FoundOperatorBeforeNumber,
                    .number_literal => {
                        const number = try Tokenizer.extractNumber(token, expression);
                        problems[i] = number;
                    },
                    .newline => break,
                    else => return error.InvalidExpression,
                }
            }

            // Remaining passes: apply operators with each subsequent number
            var problemIterator: u32 = 0;
            while (true) {
                const token = tokenizer.next();
                switch (token.tag) {
                    .bof => break,
                    .newline => {
                        problemIterator = 0;
                        continue;
                    },
                    .number_literal => {
                        const number = try Tokenizer.extractNumber(token, expression);
                        const previousNumber = problems[problemIterator];
                        const operator = operators[problemIterator];

                        problems[problemIterator] = switch (operator) {
                            .add => previousNumber + number,
                            .subtract => previousNumber - number,
                            .multiply => previousNumber * number,
                            .divide => @divTrunc(previousNumber, number),
                        };
                        problemIterator += 1;
                    },
                    else => @panic("Invalid token in expression."),
                }
            }

            var total: i128 = 0;
            for (problems) |result| {
                total += result;
            }

            return total;
        }
    };
}

/// Column-based interpreter logic for Part 2
/// Expects: numbers first, then operator per problem (reading columns right-to-left)
fn ColumnBasedLogic(comptime maxDigits: usize) type {
    return struct {
        const Tokenizer = ColumnBasedTokenizer(maxDigits);
        const Token = CephalopodMathToken(maxDigits);

        const Operator = enum {
            add,
            subtract,
            multiply,
            divide,
        };

        fn tagToOperator(tag: Token.Tag) ?Operator {
            return switch (tag) {
                .asterisk => .multiply,
                .plus => .add,
                .hyphen => .subtract,
                .slash => .divide,
                else => null,
            };
        }

        fn applyOperator(operator: Operator, accumulator: i128, value: i128) i128 {
            return switch (operator) {
                .add => accumulator + value,
                .subtract => accumulator - value,
                .multiply => accumulator * value,
                .divide => @divTrunc(accumulator, value),
            };
        }

        pub fn evaluate(expression: []const u8) !i128 {
            var tokenizer = Tokenizer.init(expression);
            var total: i128 = 0;

            while (true) {
                var numbers: [maxDigits]i128 = @splat(0);
                var num_count: usize = 0;
                var operator: Operator = undefined;
                var found_operator = false;

                // Collect numbers until we hit an operator
                while (true) {
                    const token = tokenizer.next();

                    if (tagToOperator(token.tag)) |op| {
                        operator = op;
                        found_operator = true;
                        break;
                    }

                    switch (token.tag) {
                        .bof => {
                            if (num_count > 0 and found_operator) {
                                var problem_result: i128 = numbers[0];
                                for (1..num_count) |i| {
                                    problem_result = applyOperator(operator, problem_result, numbers[i]);
                                }
                                total += problem_result;
                            }
                            return total;
                        },
                        .number_literal => {
                            const number = try Tokenizer.extractNumber(token, expression);
                            numbers[num_count] = number;
                            num_count += 1;
                        },
                        else => continue,
                    }
                }

                // Apply operator to all numbers in this problem
                if (num_count > 0 and found_operator) {
                    var problem_result: i128 = numbers[0];
                    for (1..num_count) |i| {
                        problem_result = applyOperator(operator, problem_result, numbers[i]);
                    }
                    total += problem_result;
                }
            }
        }
    };
}

fn CephalopodMathInterpreter(comptime Logic: type) type {
    return struct {
        const Self = @This();

        logic: Logic,

        pub fn init() Self {
            return Self{ .logic = Logic{} };
        }

        pub fn evaluate(expression: []const u8) !i128 {
            return Logic.evaluate(expression);
        }
    };
}

const Interpreter_Part1_Example = CephalopodMathInterpreter(RowBasedLogic(3, 4));
const Interpreter_Part1 = CephalopodMathInterpreter(RowBasedLogic(4, 1000));

const Interpreter_Part2_Example = CephalopodMathInterpreter(ColumnBasedLogic(3));
const Interpreter_Part2 = CephalopodMathInterpreter(ColumnBasedLogic(4));

test "Example Pattern Part 1" {
    try std.testing.expectEqual(4277556, try Interpreter_Part1_Example.evaluate(examplePattern1));
}

test "Minimal Example Pattern Part 1" {
    const Interpreter = CephalopodMathInterpreter(RowBasedLogic(1, 2));
    try std.testing.expectEqual(9, try Interpreter.evaluate(examplePattern2));
}

pub fn Solution_Part_One() !i128 {
    return try Interpreter_Part1.evaluate(finalPattern);
}

test "Solution Part One" {
    const result = try Solution_Part_One();
    try std.testing.expectEqual(solutions.DaySix.value(.PartOne), result);
}

test "Example Pattern Part 2" {
    try std.testing.expectEqual(3263827, try Interpreter_Part2_Example.evaluate(examplePattern1));
}

test "Minimal Example Pattern Part 2" {
    const Interpreter = CephalopodMathInterpreter(ColumnBasedLogic(2));
    try std.testing.expectEqual(37, try Interpreter.evaluate(examplePattern2));
}

pub fn Solution_Part_Two() !i128 {
    return try Interpreter_Part2.evaluate(finalPattern);
}

test "Solution Part Two" {
    const result = try Solution_Part_Two();
    try std.testing.expectEqual(solutions.DaySix.value(.PartTwo), result);
}
