const std = @import("std");
const utils = @import("utils");

// Check if a point is on a line segment between two points
fn isOnSegment(px: i64, py: i64, x1: i64, y1: i64, x2: i64, y2: i64) bool {
    // Point must be within bounding box
    const min_x = @min(x1, x2);
    const max_x = @max(x1, x2);
    const min_y = @min(y1, y2);
    const max_y = @max(y1, y2);
    
    if (px < min_x or px > max_x or py < min_y or py > max_y) {
        return false;
    }
    
    // Check if point is collinear using cross product
    const dx1 = px - x1;
    const dy1 = py - y1;
    const dx2 = x2 - x1;
    const dy2 = y2 - y1;
    
    return (dx1 * dy2 - dy1 * dx2) == 0;
}

// Check if point is on the polygon boundary
fn isOnBoundary(px: i64, py: i64, vertices: []const [2]i64) bool {
    const n = vertices.len;
    for (0..n) |i| {
        const next = (i + 1) % n;
        if (isOnSegment(px, py, vertices[i][0], vertices[i][1], vertices[next][0], vertices[next][1])) {
            return true;
        }
    }
    return false;
}

// Ray casting algorithm to check if a point is inside a polygon
fn isInsidePolygon(px: i64, py: i64, vertices: []const [2]i64) bool {
    const n = vertices.len;
    var inside = false;
    
    var j: usize = n - 1;
    for (0..n) |i| {
        const xi = vertices[i][0];
        const yi = vertices[i][1];
        const xj = vertices[j][0];
        const yj = vertices[j][1];
        
        // Check if ray from point crosses edge
        if (((yi > py) != (yj > py)) and 
            (px < @divTrunc((xj - xi) * (py - yi), (yj - yi)) + xi)) {
            inside = !inside;
        }
        j = i;
    }
    
    return inside;
}

// Check if point is valid (on boundary or inside polygon)
fn isValidPoint(px: i64, py: i64, vertices: []const [2]i64) bool {
    return isOnBoundary(px, py, vertices) or isInsidePolygon(px, py, vertices);
}

// Check if a rectangle defined by two opposite corners is valid
fn isValidRectangle(x1: i64, y1: i64, x2: i64, y2: i64, vertices: []const [2]i64) bool {
    const min_x = @min(x1, x2);
    const max_x = @max(x1, x2);
    const min_y = @min(y1, y2);
    const max_y = @max(y1, y2);
    
    // Check all points in the rectangle
    var y = min_y;
    while (y <= max_y) : (y += 1) {
        var x = min_x;
        while (x <= max_x) : (x += 1) {
            if (!isValidPoint(x, y, vertices)) {
                return false;
            }
        }
    }
    
    return true;
}

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

    // Find the largest valid rectangle
    var largest_area: u64 = 0;
    const N = coordinates.items.len;
    
    for (0..N) |i| {
        for (i+1..N) |j| {
            const x1 = coordinates.items[i][0];
            const y1 = coordinates.items[i][1];
            const x2 = coordinates.items[j][0];
            const y2 = coordinates.items[j][1];
            
            // Check if this rectangle is valid
            if (isValidRectangle(x1, y1, x2, y2, coordinates.items)) {
                const dx = @abs(x1 - x2) + 1;
                const dy = @abs(y1 - y2) + 1;
                const area = dx * dy;
                
                if (area > largest_area) {
                    largest_area = area;
                    std.debug.print("Valid rectangle ({},{}) x ({},{}) -> {}\n", .{
                        x1, y1, x2, y2, area
                    });
                }
            }
        }
    }

    std.debug.print("Largest area: {}\n", .{largest_area});
}
