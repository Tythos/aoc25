const std = @import("std");
const utils = @import("utils");

fn get_cell_index(i: usize, j: usize, I: usize, J: usize) usize {
    _ = I;
    return i * J + j;
}

pub fn main() !void {
    // define program allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // read input from stdin
    const stdin = try utils.read_from_stdin(allocator);
    defer allocator.free(stdin);

    // split into lines, each line (stripped) split by whitespace
    const lines = try utils.split_string_by_delimiter(allocator, stdin, "\n");
    defer lines.deinit();
    var first_length: usize = 0;
    var all_parts = std.ArrayList([]const u8).init(allocator);
    defer all_parts.deinit();
    for (lines.items, 0..) |line, i| {
        const parts: std.ArrayList([]const u8) = try utils.split_string_by_delimiter(allocator, line, " ");
        defer parts.deinit();
        if (i == 0) {
            first_length = parts.items.len;
        } else {
            if (parts.items.len != first_length) {
                std.debug.print("Number of parts {} is not equal to first line\n", .{i});
                return error.InvalidNumberOfParts;
            }
        }
        for (parts.items) |part| {
            try all_parts.append(part);
        }
    }

    const J: usize = first_length;
    const I: usize = @divFloor(all_parts.items.len, J);
    std.debug.print("there are {} rows and {} columns\n", .{I, J});

    // step through columns and perform arithmetic
    var grand_total: u64 = 0;
    for (0..J) |j| {
        const op = all_parts.items[get_cell_index(I-1, j, I, J)];
        // std.debug.print("operator: {s}\n", .{op});
        switch (op[0]) {
            '+' => {
                var result: u64 = 0;
                for (0..I-1) |i| {
                    const cell = all_parts.items[get_cell_index(i, j, I, J)];
                    result += std.fmt.parseInt(u64, cell, 10) catch return error.InvalidNumber;
                }
                // std.debug.print("sum: {}\n", .{result});
                grand_total += result;
            },
            '*' => {
                var result: u64 = 1;
                for (0..I-1) |i| {
                    const cell = all_parts.items[get_cell_index(i, j, I, J)];
                    result *= std.fmt.parseInt(u64, cell, 10) catch return error.InvalidNumber;
                }
                // std.debug.print("product: {}\n", .{result});
                grand_total += result;
            },
            else => {
                std.debug.print("invalid operator: {c}\n", .{all_parts.items[I-1][j]});
                return error.InvalidOperator;
            }
        }
    }
    std.debug.print("grand total: {}\n", .{grand_total});
}
