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
        if (range.len == 0) continue;
        try parts.append(range);
    }
    return parts;
}
