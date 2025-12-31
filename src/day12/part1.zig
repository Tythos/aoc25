const std = @import("std");
const utils = @import("utils");

const MAX_SHAPE_SIZE = 3;
const MAX_SHAPES = 16;
const MAX_GRID_WIDTH = 64;
const MAX_GRID_HEIGHT = 64;

// A shape is represented as a list of (row, col) offsets from top-left
const Point = struct {
    row: i32,
    col: i32,
};

const Shape = struct {
    points: [9]Point,
    num_points: usize,
    width: usize,
    height: usize,
};

// Generate all 8 orientations (4 rotations x 2 flips) of a shape
fn generateOrientations(base: Shape) [8]Shape {
    var orientations: [8]Shape = undefined;
    
    // Start with the base shape
    var current = base;
    
    // Generate 4 rotations
    for (0..4) |r| {
        orientations[r] = normalizeShape(current);
        // Rotate 90 degrees clockwise: (row, col) -> (col, -row)
        var rotated: Shape = undefined;
        rotated.num_points = current.num_points;
        for (0..current.num_points) |i| {
            rotated.points[i] = .{
                .row = current.points[i].col,
                .col = -current.points[i].row,
            };
        }
        current = rotated;
    }
    
    // Flip horizontally: (row, col) -> (row, -col)
    current = base;
    for (0..current.num_points) |i| {
        current.points[i].col = -current.points[i].col;
    }
    
    // Generate 4 rotations of flipped shape
    for (0..4) |r| {
        orientations[4 + r] = normalizeShape(current);
        var rotated: Shape = undefined;
        rotated.num_points = current.num_points;
        for (0..current.num_points) |i| {
            rotated.points[i] = .{
                .row = current.points[i].col,
                .col = -current.points[i].row,
            };
        }
        current = rotated;
    }
    
    return orientations;
}

// Normalize shape so all points have non-negative coordinates starting from 0
fn normalizeShape(shape: Shape) Shape {
    var result = shape;
    var min_row: i32 = std.math.maxInt(i32);
    var min_col: i32 = std.math.maxInt(i32);
    var max_row: i32 = std.math.minInt(i32);
    var max_col: i32 = std.math.minInt(i32);
    
    for (0..shape.num_points) |i| {
        min_row = @min(min_row, shape.points[i].row);
        min_col = @min(min_col, shape.points[i].col);
        max_row = @max(max_row, shape.points[i].row);
        max_col = @max(max_col, shape.points[i].col);
    }
    
    for (0..shape.num_points) |i| {
        result.points[i].row -= min_row;
        result.points[i].col -= min_col;
    }
    
    result.height = @intCast(max_row - min_row + 1);
    result.width = @intCast(max_col - min_col + 1);
    
    return result;
}

// Parse a shape from lines
fn parseShape(lines: []const []const u8) Shape {
    var shape: Shape = undefined;
    shape.num_points = 0;
    
    for (lines, 0..) |line, row| {
        for (line, 0..) |ch, col| {
            if (ch == '#') {
                shape.points[shape.num_points] = .{
                    .row = @intCast(row),
                    .col = @intCast(col),
                };
                shape.num_points += 1;
            }
        }
    }
    
    shape.width = if (lines.len > 0) lines[0].len else 0;
    shape.height = lines.len;
    
    return shape;
}

const Grid = struct {
    cells: [MAX_GRID_HEIGHT][MAX_GRID_WIDTH]bool,
    width: usize,
    height: usize,
    
    fn init(width: usize, height: usize) Grid {
        var grid: Grid = undefined;
        grid.width = width;
        grid.height = height;
        for (0..height) |r| {
            for (0..width) |c| {
                grid.cells[r][c] = false;
            }
        }
        return grid;
    }
    
    fn canPlace(self: *const Grid, shape: Shape, start_row: usize, start_col: usize) bool {
        for (0..shape.num_points) |i| {
            const r = start_row + @as(usize, @intCast(shape.points[i].row));
            const c = start_col + @as(usize, @intCast(shape.points[i].col));
            if (r >= self.height or c >= self.width) return false;
            if (self.cells[r][c]) return false;
        }
        return true;
    }
    
    fn place(self: *Grid, shape: Shape, start_row: usize, start_col: usize) void {
        for (0..shape.num_points) |i| {
            const r = start_row + @as(usize, @intCast(shape.points[i].row));
            const c = start_col + @as(usize, @intCast(shape.points[i].col));
            self.cells[r][c] = true;
        }
    }
    
    fn remove(self: *Grid, shape: Shape, start_row: usize, start_col: usize) void {
        for (0..shape.num_points) |i| {
            const r = start_row + @as(usize, @intCast(shape.points[i].row));
            const c = start_col + @as(usize, @intCast(shape.points[i].col));
            self.cells[r][c] = false;
        }
    }
};

// All orientations for each shape
const ShapeOrientations = struct {
    orientations: [8]Shape,
    unique_count: usize,
};

fn getUniqueOrientations(base: Shape) ShapeOrientations {
    var result: ShapeOrientations = undefined;
    const all_orientations = generateOrientations(base);
    
    result.unique_count = 0;
    
    outer: for (all_orientations) |orient| {
        // Check if this orientation is already in our unique list
        for (0..result.unique_count) |i| {
            if (shapesEqual(result.orientations[i], orient)) {
                continue :outer;
            }
        }
        result.orientations[result.unique_count] = orient;
        result.unique_count += 1;
    }
    
    return result;
}

fn shapesEqual(a: Shape, b: Shape) bool {
    if (a.num_points != b.num_points or a.width != b.width or a.height != b.height) return false;
    
    // Sort points and compare
    var points_a: [9]Point = undefined;
    var points_b: [9]Point = undefined;
    for (0..a.num_points) |i| {
        points_a[i] = a.points[i];
        points_b[i] = b.points[i];
    }
    
    // Simple bubble sort for small arrays
    for (0..a.num_points) |i| {
        for (i + 1..a.num_points) |j| {
            if (pointLess(points_a[j], points_a[i])) {
                const tmp = points_a[i];
                points_a[i] = points_a[j];
                points_a[j] = tmp;
            }
            if (pointLess(points_b[j], points_b[i])) {
                const tmp = points_b[i];
                points_b[i] = points_b[j];
                points_b[j] = tmp;
            }
        }
    }
    
    for (0..a.num_points) |i| {
        if (points_a[i].row != points_b[i].row or points_a[i].col != points_b[i].col) return false;
    }
    return true;
}

fn pointLess(a: Point, b: Point) bool {
    if (a.row != b.row) return a.row < b.row;
    return a.col < b.col;
}

// Solve: try to place all shapes in the grid
fn solve(
    grid: *Grid,
    shape_orientations: []const ShapeOrientations,
    shape_counts: []usize,
    shape_index: usize,
) bool {
    // Skip shapes with count 0
    var idx = shape_index;
    while (idx < shape_counts.len and shape_counts[idx] == 0) {
        idx += 1;
    }
    
    // All shapes placed
    if (idx >= shape_counts.len) return true;
    
    const orientations = &shape_orientations[idx];
    
    // Try each orientation
    for (0..orientations.unique_count) |o| {
        const shape = orientations.orientations[o];
        
        // Try each position
        for (0..grid.height) |r| {
            if (r + shape.height > grid.height) break;
            for (0..grid.width) |c| {
                if (c + shape.width > grid.width) continue;
                
                if (grid.canPlace(shape, r, c)) {
                    grid.place(shape, r, c);
                    shape_counts[idx] -= 1;
                    
                    if (solve(grid, shape_orientations, shape_counts, idx)) {
                        shape_counts[idx] += 1;
                        grid.remove(shape, r, c);
                        return true;
                    }
                    
                    shape_counts[idx] += 1;
                    grid.remove(shape, r, c);
                }
            }
        }
    }
    
    return false;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Read input from stdin
    const stdin = try utils.read_from_stdin(allocator);
    defer allocator.free(stdin);
    
    // Split into sections by double newline
    var sections = std.ArrayList([]const u8).init(allocator);
    defer sections.deinit();
    
    var section_iter = std.mem.splitSequence(u8, stdin, "\n\n");
    while (section_iter.next()) |section| {
        const trimmed = utils.strip_string(section);
        if (trimmed.len > 0) {
            try sections.append(trimmed);
        }
    }
    
    // Parse shapes from first section(s)
    var base_shapes: [MAX_SHAPES]Shape = undefined;
    var shape_count: usize = 0;
    
    // Find where regions start (lines that contain 'x')
    var region_start_section: usize = 0;
    
    for (sections.items, 0..) |section, section_idx| {
        var lines_iter = std.mem.splitScalar(u8, section, '\n');
        const first_line = lines_iter.next() orelse continue;
        
        if (utils.contains(first_line, "x")) {
            region_start_section = section_idx;
            break;
        }
        
        // This is a shape definition
        // First line should be "N:" where N is the index
        if (utils.contains(first_line, ":")) {
            var shape_lines: [3][]const u8 = undefined;
            var line_count: usize = 0;
            
            while (lines_iter.next()) |line| {
                if (line.len == 0) continue;
                shape_lines[line_count] = line;
                line_count += 1;
                if (line_count >= 3) break;
            }
            
            base_shapes[shape_count] = parseShape(shape_lines[0..line_count]);
            shape_count += 1;
        }
    }
    
    // Pre-compute all orientations for each shape
    var all_orientations: [MAX_SHAPES]ShapeOrientations = undefined;
    for (0..shape_count) |i| {
        all_orientations[i] = getUniqueOrientations(base_shapes[i]);
    }
    
    // First, count total regions for progress reporting
    var total_regions: usize = 0;
    for (region_start_section..sections.items.len) |section_idx| {
        const section = sections.items[section_idx];
        var count_iter = std.mem.splitScalar(u8, section, '\n');
        while (count_iter.next()) |line| {
            const trimmed = utils.strip_string(line);
            if (trimmed.len > 0 and utils.contains(trimmed, "x")) {
                total_regions += 1;
            }
        }
    }
    
    // Parse and solve regions
    var valid_regions: usize = 0;
    var current_region: usize = 0;
    
    const stderr = std.io.getStdErr().writer();
    
    for (region_start_section..sections.items.len) |section_idx| {
        const section = sections.items[section_idx];
        var lines_iter = std.mem.splitScalar(u8, section, '\n');
        
        while (lines_iter.next()) |line| {
            const trimmed = utils.strip_string(line);
            if (trimmed.len == 0) continue;
            if (!utils.contains(trimmed, "x")) continue;
            
            current_region += 1;
            
            // Parse "WxH: c0 c1 c2 ..."
            const colon_pos = std.mem.indexOf(u8, trimmed, ":") orelse continue;
            const size_part = trimmed[0..colon_pos];
            const counts_part = utils.strip_string(trimmed[colon_pos + 1..]);
            
            // Parse WxH
            const x_pos = std.mem.indexOf(u8, size_part, "x") orelse continue;
            const width = std.fmt.parseInt(usize, size_part[0..x_pos], 10) catch continue;
            const height = std.fmt.parseInt(usize, size_part[x_pos + 1..], 10) catch continue;
            
            // Parse counts
            var shape_counts: [MAX_SHAPES]usize = [_]usize{0} ** MAX_SHAPES;
            var counts_iter = std.mem.splitScalar(u8, counts_part, ' ');
            var count_idx: usize = 0;
            while (counts_iter.next()) |count_str| {
                if (count_str.len == 0) continue;
                shape_counts[count_idx] = std.fmt.parseInt(usize, count_str, 10) catch 0;
                count_idx += 1;
            }
            
            // Quick area check - if total shape area exceeds grid area, skip
            const grid_area = width * height;
            var shape_area: usize = 0;
            for (0..shape_count) |i| {
                shape_area += base_shapes[i].num_points * shape_counts[i];
            }
            
            var solvable = false;
            if (shape_area <= grid_area) {
                // Try to solve
                var grid = Grid.init(width, height);
                solvable = solve(&grid, all_orientations[0..shape_count], shape_counts[0..shape_count], 0);
            }
            
            if (solvable) {
                valid_regions += 1;
            }
            
            // Report progress
            try stderr.print("\rProcessing region {}/{} ({s})... valid so far: {}   ", .{ current_region, total_regions, size_part, valid_regions });
        }
    }
    
    // Clear progress line and print newline
    try stderr.print("\r{s}\r", .{" " ** 80});
    
    // Print result to stdout
    const stdout = std.io.getStdOut().writer();
    try stdout.print("{}\n", .{valid_regions});
}
