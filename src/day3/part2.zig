const std = @import("std");
const utils = @import("utils");

fn get_highest_digit_between(line: []const u8, start: usize, stop: usize) usize {
    // given string of digits, returns index of highest digit between start (inclusive) and stop (exclusive)
    var i_highest = start;
    var v_highest = std.fmt.parseInt(u8, line[i_highest..i_highest+1], 10) catch return 0;
    for (start+1..stop) |i| {
        const v = std.fmt.parseInt(u8, line[i..i+1], 10) catch return 0;
        if (v > v_highest) {
            i_highest = i;
            v_highest = v;
        }
    }
    return i_highest;
}

fn get_highest_k_digit_number(line: []const u8, k: usize) !u64 {
    // much like part 1, we will select k digits from left to right to maximize the resulting number
    var result: u64 = 0;
    var current_index: usize = 0;
    
    // then, for each position, find the highest digit between its predecessor and the next digit
    for (0..k) |i| {
        const remaining_positions = k - i - 1;
        const search_end = line.len - remaining_positions;
        const highest_idx = get_highest_digit_between(line, current_index, search_end);
        const digit_value = std.fmt.parseInt(u8, line[highest_idx..highest_idx+1], 10) catch return 0;
        result = result * 10 + digit_value;
        current_index = highest_idx + 1;
    }
    
    return result;
}

pub fn main() !void {
    // define allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var total: u64 = 0;

    // iterate over stdin lines
    const stdin = try utils.read_from_stdin(allocator);
    defer allocator.free(stdin);
    const lines = try utils.split_string_by_delimiter(allocator, stdin, "\n");
    defer lines.deinit();
    for (lines.items) |line| {
        const highest = try get_highest_k_digit_number(line, 12);
        std.debug.print("highest: {}\n", .{highest});
        total += highest;
    }
    std.debug.print("total: {}\n", .{total});
}
