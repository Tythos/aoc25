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

    // file will have two parts separated by a double-newline
    const parts = try utils.split_string_by_delimiter(allocator, stdin, "\n\n");
    defer parts.deinit();
    std.debug.assert(parts.items.len == 2);

    // parse ranges into start/stop integer pairs
    const ranges = try utils.split_string_by_delimiter(allocator, parts.items[0], "\n");
    defer ranges.deinit();
    var fresh_ingredient_ranges = std.ArrayList(struct { u64, u64 }).init(allocator);
    defer fresh_ingredient_ranges.deinit();
    for (ranges.items) |range| {
        const limits = try utils.split_string_by_delimiter(allocator, range, "-");
        defer limits.deinit();
        const start = std.fmt.parseInt(u64, limits.items[0], 10) catch return error.InvalidRange;
        const stop = std.fmt.parseInt(u64, limits.items[1], 10) catch return error.InvalidRange;
        fresh_ingredient_ranges.append(.{ start, stop }) catch return error.OutOfMemory;
    }

    // sort ranges by start position
    const Range = struct { start: u64, stop: u64 };
    var sorted_ranges = std.ArrayList(Range).init(allocator);
    defer sorted_ranges.deinit();
    for (fresh_ingredient_ranges.items) |range| {
        try sorted_ranges.append(.{ .start = range[0], .stop = range[1] });
    }
    std.mem.sort(Range, sorted_ranges.items, {}, struct {
        fn lessThan(_: void, a: Range, b: Range) bool {
            return a.start < b.start;
        }
    }.lessThan);

    // merge overlapping ranges
    var merged_ranges = std.ArrayList(Range).init(allocator);
    defer merged_ranges.deinit();
    
    if (sorted_ranges.items.len > 0) {
        var current = sorted_ranges.items[0];
        
        for (sorted_ranges.items[1..]) |range| {
            // if ranges overlap or are adjacent, merge them
            if (range.start <= current.stop + 1) {
                current.stop = @max(current.stop, range.stop);
            } else {
                // no overlap, save current and start new range
                try merged_ranges.append(current);
                current = range;
            }
        }
        // don't forget the last range
        try merged_ranges.append(current);
    }

    // count total unique IDs in all merged ranges
    var total_fresh_ids: u64 = 0;
    for (merged_ranges.items) |range| {
        total_fresh_ids += range.stop - range.start + 1;
    }
    
    std.debug.print("total number of fresh ingredient IDs: {}\n", .{total_fresh_ids});
}
