const std = @import("std");
const utils = @import("utils");

const VerticalSegment = struct { x: i64, min_y: i64, max_y: i64 };
const HorizontalSegment = struct { y: i64, min_x: i64, max_x: i64 };

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

    // map each line into a coordinate pair
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

    const N = coordinates.items.len;

    // Precompute red tiles set for O(1) lookup
    var red_tiles = std.AutoHashMap([2]i64, void).init(allocator);
    defer red_tiles.deinit();
    for (coordinates.items) |coord| {
        try red_tiles.put(coord, {});
    }

    // Precompute boundary segments 
    var vertical_segments = std.ArrayList(VerticalSegment).init(allocator);
    defer vertical_segments.deinit();
    var horizontal_segments = std.ArrayList(HorizontalSegment).init(allocator);
    defer horizontal_segments.deinit();
    
    for (0..N) |i| {
        const next_i = (i + 1) % N;
        const p1 = coordinates.items[i];
        const p2 = coordinates.items[next_i];
        
        if (p1[0] == p2[0]) {
            // Vertical segment
            try vertical_segments.append(VerticalSegment{
                .x = p1[0],
                .min_y = @min(p1[1], p2[1]),
                .max_y = @max(p1[1], p2[1]),
            });
        } else if (p1[1] == p2[1]) {
            // Horizontal segment
            try horizontal_segments.append(HorizontalSegment{
                .y = p1[1],
                .min_x = @min(p1[0], p2[0]),
                .max_x = @max(p1[0], p2[0]),
            });
        }
    }

    // Find the largest valid rectangle
    var largest_area: u64 = 0;
    
    // Optimization: Process largest potential rectangles first
    var pairs = std.ArrayList(struct { i: usize, j: usize, area: u64 }).init(allocator);
    defer pairs.deinit();
    
    for (0..N) |i| {
        for (i + 1..N) |j| {
            const p1 = coordinates.items[i];
            const p2 = coordinates.items[j];
            const dx = if (p1[0] > p2[0]) p1[0] - p2[0] else p2[0] - p1[0];
            const dy = if (p1[1] > p2[1]) p1[1] - p2[1] else p2[1] - p1[1];
            const area: u64 = @intCast((dx + 1) * (dy + 1));
            try pairs.append(.{ .i = i, .j = j, .area = area });
        }
    }
    
    // Sort pairs by area in descending order for early exit
    std.mem.sort(@TypeOf(pairs.items[0]), pairs.items, {}, struct {
        fn compare(_: void, a: @TypeOf(pairs.items[0]), b: @TypeOf(pairs.items[0])) bool {
            return a.area > b.area;
        }
    }.compare);
    
    for (pairs.items) |pair| {
        // Early exit if no better solution is possible
        if (pair.area <= largest_area) break;
        
        const p1 = coordinates.items[pair.i];
        const p2 = coordinates.items[pair.j];
        
        // Calculate rectangle bounds
        const min_x = @min(p1[0], p2[0]);
        const max_x = @max(p1[0], p2[0]);
        const min_y = @min(p1[1], p2[1]);
        const max_y = @max(p1[1], p2[1]);
        
        // Check if all points in rectangle are red or green
        var all_valid = true;
        var y = min_y;
        while (y <= max_y and all_valid) : (y += 1) {
            var x = min_x;
            while (x <= max_x and all_valid) : (x += 1) {
                const point = [2]i64{ x, y };
                if (!isRedOrGreen(point, coordinates.items, &red_tiles, vertical_segments.items, horizontal_segments.items)) {
                    all_valid = false;
                }
            }
        }
        
        if (all_valid) {
            largest_area = pair.area;
            break; // Since sorted by area descending, this is optimal
        }
    }

    std.debug.print("largest area: {}\n", .{largest_area});
}

fn isRedOrGreen(
    point: [2]i64,
    polygon: [][2]i64,
    red_tiles: *const std.AutoHashMap([2]i64, void),
    vertical_segments: []const VerticalSegment,
    horizontal_segments: []const HorizontalSegment,
) bool {
    // Check if point is a red tile (O(1) lookup)
    if (red_tiles.contains(point)) {
        return true;
    }
    
    // Check if point is on a vertical boundary segment
    for (vertical_segments) |seg| {
        if (point[0] == seg.x and point[1] >= seg.min_y and point[1] <= seg.max_y) {
            return true;
        }
    }
    
    // Check if point is on a horizontal boundary segment
    for (horizontal_segments) |seg| {
        if (point[1] == seg.y and point[0] >= seg.min_x and point[0] <= seg.max_x) {
            return true;
        }
    }
    
    // Check if point is inside the polygon (green tiles inside the loop)
    // Using ray casting algorithm
    const n = polygon.len;
    var inside = false;
    var j: usize = n - 1;
    for (0..n) |i| {
        const xi = polygon[i][0];
        const yi = polygon[i][1];
        const xj = polygon[j][0];
        const yj = polygon[j][1];
        
        const yi_above = yi > point[1];
        const yj_above = yj > point[1];
        
        if (yi_above != yj_above) {
            const dy = yj - yi;
            if (dy != 0) {
                const left_side = point[0] * dy;
                const right_side = xi * dy + (point[1] - yi) * (xj - xi);
                
                if ((dy > 0 and left_side < right_side) or (dy < 0 and left_side > right_side)) {
                    inside = !inside;
                }
            }
        }
        j = i;
    }
    
    return inside;
}
