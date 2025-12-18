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
    const lines = try utils.split_string_by_delimiter(allocator, stdin, "\n");
    defer utils.free_string_list(allocator, lines);

    // map each line into a coordinate pairt
    var coordinates = std.ArrayList([2]i64).init(allocator);
    defer coordinates.deinit();
    for (lines.items) |line| {
        if (line.len == 0) continue;
        const parts = try utils.split_string_by_delimiter(allocator, line, ",");
        defer utils.free_string_list(allocator, parts);
        const x = std.fmt.parseInt(i64, parts.items[0], 10) catch return error.InvalidX;
        const y = std.fmt.parseInt(i64, parts.items[1], 10) catch return error.InvalidY;
        try coordinates.append(.{ x, y });
    }

    // construct triangular area matrix
    const N = coordinates.items.len;
    var area_matrix = std.ArrayList(u64).init(allocator);
    defer area_matrix.deinit();
    for (0..N) |i| {
        for (i+1..N) |j| {
            const dx = coordinates.items[i][0] - coordinates.items[j][0];
            const dy = coordinates.items[i][1] - coordinates.items[j][1];
            try area_matrix.append(@abs((dx + 1) * (dy + 1)));
            std.debug.print("({},{}) x ({},{}) -> {}\n", .{
                coordinates.items[i][0], coordinates.items[i][1],
                coordinates.items[j][0], coordinates.items[j][1],
                @abs((dx + 1) * (dy + 1)),
            });
        }
    }

    // resoslve largest area
    var largest_index: usize = 0;
    var largest_area: u64 = 0;
    for (area_matrix.items, 0..) |area, i| {
        if (area > largest_area) {
            largest_area = area;
            largest_index = i;
        }
    }
    std.debug.print("largest area: {}\n", .{largest_area});
    std.debug.print("largest index: {}\n", .{largest_index});
}
