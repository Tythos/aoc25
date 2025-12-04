const std = @import("std");
const utils = @import("utils");

fn get_selection_value(line: []const u8, dL: u8, dR: u8) !u8 {
    const nL = std.fmt.parseInt(u8, line[dL..dL+1], 10) catch return 0;
    const nR = std.fmt.parseInt(u8, line[dR..dR+1], 10) catch return 0;
    return nL * 10 + nR;
}

fn get_highest_digit_between(line: []const u8, start: u8, stop: u8) u8 {
    // given string of digits, returns index of higest digit between start (inclusive) and stop (exclusive)
    var i_highest = start;
    var v_highest = std.fmt.parseInt(u8, line[i_highest..i_highest+1], 10) catch return 0;
    for (start+1..stop) |i| {
        const i_u8 = @as(u8, @intCast(i));
        const v = std.fmt.parseInt(u8, line[i..i+1], 10) catch return 0;
        if (v > v_highest) {
            i_highest = i_u8;
            v_highest = v;
        }
    }
    return i_highest;
}

fn get_highest_number_in_line(line: []const u8) u8 {
    const len = @as(u8, @intCast(line.len));
    const hL = get_highest_digit_between(line, 0, len-1);
    const hR = get_highest_digit_between(line, hL+1, len);
    return get_selection_value(line, hL, hR) catch return 0;
}

pub fn main() !void {
    // define allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var total: u16 = 0;

    // iterate over stdin lines
    const stdin = try utils.read_from_stdin(allocator);
    defer allocator.free(stdin);
    const lines = try utils.split_string_by_delimiter(allocator, stdin, "\n");
    defer lines.deinit();
    for (lines.items) |line| {
        const highest = get_highest_number_in_line(line);
        std.debug.print("highest: {}\n", .{highest});
        total += highest;
    }
    std.debug.print("total: {}\n", .{total});
}
