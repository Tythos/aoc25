const std = @import("std");
const utils = @import("utils");

pub fn main() !void {
    // define program allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // read input from stdin
    const stdin = try utils.read_from_stdin(allocator);
    defer allocator.free(stdin);

    // split into lines (preserve whitespace - don't split by spaces!)
    const lines = try utils.split_string_by_delimiter(allocator, stdin, "\n");
    defer lines.deinit();

    // Find the maximum line length and pad all lines to that length
    var max_length: usize = 0;
    for (lines.items) |line| {
        if (line.len > max_length) {
            max_length = line.len;
        }
    }

    // Create a 2D character grid
    var grid = std.ArrayList([]u8).init(allocator);
    defer {
        for (grid.items) |row| {
            allocator.free(row);
        }
        grid.deinit();
    }

    for (lines.items) |line| {
        var row = try allocator.alloc(u8, max_length);
        @memset(row, ' ');
        @memcpy(row[0..line.len], line);
        try grid.append(row);
    }

    const num_rows = grid.items.len;
    const num_cols = max_length;

    std.debug.print("Grid: {} rows x {} columns\n", .{ num_rows, num_cols });

    // Process columns right-to-left
    var grand_total: u64 = 0;
    var current_problem_numbers = std.ArrayList(u64).init(allocator);
    defer current_problem_numbers.deinit();
    var current_problem_op: ?u8 = null;

    var j: usize = num_cols;
    while (j > 0) {
        j -= 1;

        // Extract column characters
        var is_separator = true;
        var number_str = std.ArrayList(u8).init(allocator);
        defer number_str.deinit();

        // Read column top-to-bottom (skip last row for now to check operator)
        for (0..num_rows - 1) |i| {
            const c = grid.items[i][j];
            if (c != ' ') {
                is_separator = false;
                try number_str.append(c);
            }
        }

        // Get operator from last row
        const op_char = grid.items[num_rows - 1][j];

        if (is_separator) {
            // This column is a separator - process accumulated problem if any
            if (current_problem_numbers.items.len > 0 and current_problem_op != null) {
                const result = try calculate_problem(current_problem_numbers.items, current_problem_op.?);
                grand_total += result;
                current_problem_numbers.clearRetainingCapacity();
                current_problem_op = null;
            }
        } else {
            // This column is part of a problem
            const number = try std.fmt.parseInt(u64, number_str.items, 10);
            try current_problem_numbers.append(number);
            current_problem_op = op_char;
        }
    }

    // Process the last problem if any
    if (current_problem_numbers.items.len > 0 and current_problem_op != null) {
        const result = try calculate_problem(current_problem_numbers.items, current_problem_op.?);
        grand_total += result;
    }

    std.debug.print("grand total: {}\n", .{grand_total});
}

fn calculate_problem(numbers: []const u64, op: u8) !u64 {
    var result: u64 = 0;
    switch (op) {
        '+' => {
            for (numbers) |num| {
                result += num;
            }
        },
        '*' => {
            result = 1;
            for (numbers) |num| {
                result *= num;
            }
        },
        else => {
            std.debug.print("invalid operator: {c}\n", .{op});
            return error.InvalidOperator;
        },
    }
    return result;
}
