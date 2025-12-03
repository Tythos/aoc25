const std = @import("std");

/// a number is invalid if it consists of a sequence of digits that repeats exactly twice
fn is_valid(allocator: std.mem.Allocator, n: u64) bool {
    // convert number to a string
    const n_str = std.fmt.allocPrint(allocator, "{d}", .{n}) catch return false;
    const len: usize = n_str.len;
    defer allocator.free(n_str);
    if (len % 2 != 0) {
        return true;
    }

    // split string into lhs and rhs, compare
    const lhs = n_str[0..len / 2];
    const rhs = n_str[len / 2..];
    return !std.mem.eql(u8, lhs, rhs);
}

fn split_string_by_delimiter(allocator: std.mem.Allocator, content: []const u8, delimiter: []const u8) !std.ArrayList([]const u8) {
    var parts = std.ArrayList([]const u8).init(allocator);
    var iterator = std.mem.splitSequence(u8, content, delimiter);
    while (iterator.next()) |range| {
        if (range.len == 0) continue;
        try parts.append(range);
    }
    return parts;
}

// returns a string that is a copy of the input string with all occurrences of the old substring replaced with the new substring
fn string_replace(allocator: std.mem.Allocator, content: []const u8, old: []const u8, new: []const u8) ![]const u8 {
    // first break apart content using old substring as delimiter
    var parts = std.ArrayList([]const u8).init(allocator);
    defer parts.deinit();
    var iterator = std.mem.splitSequence(u8, content, old);
    while (iterator.next()) |part| {
        if (part.len == 0) continue;
        try parts.append(part);
    }

    // calculate length of new string
    var total_length: u64 = 0;
    for (parts.items) |part| {
        total_length += part.len;
    }
    total_length += (parts.items.len - 1) * new.len;
    
    // allocate returned string
    var result_str = try allocator.alloc(u8, total_length);

    // reconstruct string using new substring as concatenator
    var result_str_index: u64 = 0;
    for (parts.items, 0..parts.items.len) |part, i| {
        // copy the part
        @memcpy(result_str[result_str_index..result_str_index + part.len], part);
        result_str_index += part.len;
        if (i < parts.items.len - 1) {
            // copy the new substring
            @memcpy(result_str[result_str_index..result_str_index + new.len], new);
            result_str_index += new.len;
        }
    }
    return result_str;
}

fn read_from_stdin(allocator: std.mem.Allocator) ![]const u8 {
    // parse input from stdout into lines
    const stdin = std.io.getStdIn();
    const content = try stdin.readToEndAlloc(allocator, 1024 * 1024);
    return content;
}

pub fn main() !void {
    // define allocator, tracking variables
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var sum_invalid: u64 = 0;

    // split ranges from stdin by comma delimiter
    const content_raw = try read_from_stdin(allocator);
    defer allocator.free(content_raw);
    const content = try string_replace(allocator, content_raw, "\n", "");
    defer allocator.free(content);
    const ranges = try split_string_by_delimiter(allocator, content, ",");
    defer ranges.deinit();

    // for each range, check (and sum) invalid values
    for (ranges.items) |range| {
        // split range by dash delimiter
        var n_invalid: u64 = 0;
        const limits = try split_string_by_delimiter(allocator, range, "-");
        defer limits.deinit();
        const start: u64 = std.fmt.parseInt(u64, limits.items[0], 10) catch return error.InvalidRange;
        const end: u64 = std.fmt.parseInt(u64, limits.items[1], 10) catch return error.InvalidRange;
        for (start..(end+1)) |i| {
            const i_u64 = @as(u64, @intCast(i));
            if (!is_valid(allocator, i_u64)) {
                sum_invalid += i_u64;
                n_invalid += 1;
            }
        }
        std.debug.print("{s} has {} invalid ID{s}\n", .{ range, n_invalid, if (n_invalid == 1) "" else "s" });
    }

    std.debug.print("sum_invalid: {}\n", .{sum_invalid});
}
