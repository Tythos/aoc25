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

    // count number of ingredients IDs that are fresh
    var num_fresh_ingredients: u64 = 0;
    const ids = try utils.split_string_by_delimiter(allocator, parts.items[1], "\n");
    defer ids.deinit();
    for (ids.items) |id| {
        const id_u64 = std.fmt.parseInt(u64, id, 10) catch return error.InvalidID;
        for (fresh_ingredient_ranges.items) |range| {
            if (id_u64 >= range[0] and id_u64 <= range[1]) {
                num_fresh_ingredients += 1;
                break;
            }
        }
    }
    std.debug.print("number of fresh ingredients: {}\n", .{num_fresh_ingredients});
}
