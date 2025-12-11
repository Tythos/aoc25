const std = @import("std");

pub fn read_from_stdin(allocator: std.mem.Allocator) ![]const u8 {
    // parse input from stdout into lines
    const stdin = std.io.getStdIn();
    const content = try stdin.readToEndAlloc(allocator, 1024 * 1024);
    return content;
}

pub fn split_string_by_delimiter(allocator: std.mem.Allocator, content: []const u8, delimiter: []const u8) !std.ArrayList([]const u8) {
    var parts = std.ArrayList([]const u8).init(allocator);
    var iterator = std.mem.splitSequence(u8, content, delimiter);
    while (iterator.next()) |range| {
        if (range.len == 0) continue; // skip consecutive empty parts
        const owned_string = try allocator.dupe(u8, range);
        try parts.append(owned_string);
    }
    return parts;
}

pub fn free_string_list(allocator: std.mem.Allocator, strings: std.ArrayList([]const u8)) void {
    for (strings.items) |string| {
        allocator.free(string);
    }
    strings.deinit();
}

pub fn contains(content: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, content, needle) != null;
}

/// returns a copy of the given string with leading and trailing whitespace removed
pub fn strip_string(content: []const u8) []const u8 {
    var i_start: usize = 0;
    var i_end: usize = content.len;
    const whitespace = " \t\n\r";
    while (i_start < content.len and std.mem.indexOfScalar(u8, whitespace, content[i_start]) != null) {
        i_start += 1;
    }
    while (i_end > i_start and std.mem.indexOfScalar(u8, whitespace, content[i_end - 1]) != null) {
        i_end -= 1;
    }
    return content[i_start..i_end];
}

test "split_string" {
    const allocator = std.testing.allocator;
    const content = "farewell, cruel world!";
    const parts = try split_string_by_delimiter(allocator, content, " ");
    defer parts.deinit();
    try std.testing.expectEqual(parts.items.len, 3);
    try std.testing.expectEqualStrings("farewell,", parts.items[0]);
    try std.testing.expectEqualStrings("cruel", parts.items[1]);
    try std.testing.expectEqualStrings("world!", parts.items[2]);
}

test "strip_string" {
    const content = " \t hello world  \n";
    const result = strip_string(content);
    try std.testing.expectEqualStrings("hello world", result);
}

test "contains" {
    const content = "hello world";
    const needle = "world";
    const result = contains(content, needle);
    try std.testing.expect(result);
}