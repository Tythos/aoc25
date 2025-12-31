// --- Day 12: Christmas Tree Farm ---

// You're almost out of time, but there can't be much left to decorate. Although there are no stairs, elevators, escalators, tunnels, chutes, teleporters, firepoles, or conduits here that would take you deeper into the North Pole base, there is a ventilation duct. You jump in.

// After bumping around for a few minutes, you emerge into a large, well-lit cavern full of Christmas trees!

// There are a few Elves here frantically decorating before the deadline. They think they'll be able to finish most of the work, but the one thing they're worried about is the presents for all the young Elves that live here at the North Pole. It's an ancient tradition to put the presents under the trees, but the Elves are worried they won't fit.

// The presents come in a few standard but very weird shapes. The shapes and the regions into which they need to fit are all measured in standard units. To be aesthetically pleasing, the presents need to be placed into the regions in a way that follows a standardized two-dimensional unit grid; you also can't stack presents.

// As always, the Elves have a summary of the situation (your puzzle input) for you. First, it contains a list of the presents' shapes. Second, it contains the size of the region under each tree and a list of the number of presents of each shape that need to fit into that region. For example:

// 0:
// ###
// ##.
// ##.

// 1:
// ###
// ##.
// .##

// 2:
// .##
// ###
// ##.

// 3:
// ##.
// ###
// ##.

// 4:
// ###
// #..
// ###

// 5:
// ###
// .#.
// ###

// 4x4: 0 0 0 0 2 0
// 12x5: 1 0 1 0 2 2
// 12x5: 1 0 1 0 3 2
// The first section lists the standard present shapes. For convenience, each shape starts with its index and a colon; then, the shape is displayed visually, where # is part of the shape and . is not.

// The second section lists the regions under the trees. Each line starts with the width and length of the region; 12x5 means the region is 12 units wide and 5 units long. The rest of the line describes the presents that need to fit into that region by listing the quantity of each shape of present; 1 0 1 0 3 2 means you need to fit one present with shape index 0, no presents with shape index 1, one present with shape index 2, no presents with shape index 3, three presents with shape index 4, and two presents with shape index 5.

// Presents can be rotated and flipped as necessary to make them fit in the available space, but they have to always be placed perfectly on the grid. Shapes can't overlap (that is, the # part from two different presents can't go in the same place on the grid), but they can fit together (that is, the . part in a present's shape's diagram does not block another present from occupying that space on the grid).

// The Elves need to know how many of the regions can fit the presents listed. In the above example, there are six unique present shapes and three regions that need checking.

// The first region is 4x4:

// ....
// ....
// ....
// ....
// In it, you need to determine whether you could fit two presents that have shape index 4:

// ###
// #..
// ###
// After some experimentation, it turns out that you can fit both presents in this region. Here is one way to do it, using A to represent one present and B to represent the other:

// AAA.
// ABAB
// ABAB
// .BBB
// The second region, 12x5: 1 0 1 0 2 2, is 12 units wide and 5 units long. In that region, you need to try to fit one present with shape index 0, one present with shape index 2, two presents with shape index 4, and two presents with shape index 5.

// It turns out that these presents can all fit in this region. Here is one way to do it, again using different capital letters to represent all the required presents:

// ....AAAFFE.E
// .BBBAAFFFEEE
// DDDBAAFFCECE
// DBBB....CCC.
// DDD.....C.C.
// The third region, 12x5: 1 0 1 0 3 2, is the same size as the previous region; the only difference is that this region needs to fit one additional present with shape index 4. Unfortunately, no matter how hard you try, there is no way to fit all of the presents into this region.

// So, in this example, 2 regions can fit all of their listed presents.

// Consider the regions beneath each tree and the presents the Elves would like to fit into each of them. How many of the regions can fit all of the presents listed?


const std = @import("std");

const Shape = struct {
    cells: std.ArrayList(Pos),
    width: usize,
    height: usize,

    fn deinit(self: *Shape) void {
        self.cells.deinit();
    }
};

const Pos = struct {
    x: i32,
    y: i32,
};

const Region = struct {
    width: usize,
    height: usize,
    counts: []usize,

    fn deinit(self: *Region, allocator: std.mem.Allocator) void {
        allocator.free(self.counts);
    }
};

fn parseShapes(allocator: std.mem.Allocator, input: []const u8) !std.ArrayList(Shape) {
    var shapes = std.ArrayList(Shape).init(allocator);
    var lines = std.mem.split(u8, input, "\n");
    
    var current_shape: ?Shape = null;
    var current_lines = std.ArrayList([]const u8).init(allocator);
    defer current_lines.deinit();
    
    while (lines.next()) |line| {
        if (line.len == 0) {
            if (current_shape != null) {
                try shapes.append(current_shape.?);
                current_shape = null;
                current_lines.clearRetainingCapacity();
            }
            continue;
        }
        
        // Check if this is a region line (contains 'x')
        if (std.mem.indexOf(u8, line, "x") != null) {
            if (current_shape != null) {
                try shapes.append(current_shape.?);
                current_shape = null;
            }
            break;
        }
        
        // Check if this is a shape index line (contains ':')
        if (std.mem.indexOf(u8, line, ":") != null) {
            if (current_shape != null) {
                try shapes.append(current_shape.?);
                current_shape = null;
                current_lines.clearRetainingCapacity();
            }
            current_shape = Shape{
                .cells = std.ArrayList(Pos).init(allocator),
                .width = 0,
                .height = 0,
            };
            continue;
        }
        
        // Parse shape line
        if (current_shape != null) {
            try current_lines.append(line);
        }
    }
    
    // Process the last shape if any
    if (current_shape != null) {
        try shapes.append(current_shape.?);
    }
    
    // Now go back and parse the actual cells for each shape
    shapes.clearRetainingCapacity();
    lines = std.mem.split(u8, input, "\n");
    current_shape = null;
    current_lines.clearRetainingCapacity();
    
    while (lines.next()) |line| {
        if (line.len == 0) {
            if (current_lines.items.len > 0) {
                var shape = Shape{
                    .cells = std.ArrayList(Pos).init(allocator),
                    .width = 0,
                    .height = current_lines.items.len,
                };
                
                for (current_lines.items, 0..) |shape_line, y| {
                    if (shape_line.len > shape.width) shape.width = shape_line.len;
                    for (shape_line, 0..) |c, x| {
                        if (c == '#') {
                            try shape.cells.append(.{ .x = @intCast(x), .y = @intCast(y) });
                        }
                    }
                }
                
                try shapes.append(shape);
                current_lines.clearRetainingCapacity();
            }
            continue;
        }
        
        if (std.mem.indexOf(u8, line, "x") != null) {
            break;
        }
        
        if (std.mem.indexOf(u8, line, ":") != null) {
            continue;
        }
        
        try current_lines.append(line);
    }
    
    return shapes;
}

fn parseRegions(allocator: std.mem.Allocator, input: []const u8, num_shapes: usize) !std.ArrayList(Region) {
    var regions = std.ArrayList(Region).init(allocator);
    var lines = std.mem.split(u8, input, "\n");
    var in_regions = false;
    
    while (lines.next()) |line| {
        if (line.len == 0) {
            if (in_regions) continue;
            in_regions = true;
            continue;
        }
        
        if (!in_regions) continue;
        
        // Parse region line: "4x4: 0 0 0 0 2 0"
        var parts = std.mem.split(u8, line, ":");
        const dims_str = parts.next() orelse continue;
        const counts_str = std.mem.trim(u8, parts.next() orelse continue, " ");
        
        // Parse dimensions
        var dim_parts = std.mem.split(u8, dims_str, "x");
        const width = try std.fmt.parseInt(usize, dim_parts.next() orelse continue, 10);
        const height = try std.fmt.parseInt(usize, dim_parts.next() orelse continue, 10);
        
        // Parse counts
        var counts = try allocator.alloc(usize, num_shapes);
        var count_iter = std.mem.split(u8, counts_str, " ");
        var i: usize = 0;
        while (count_iter.next()) |count_str| {
            if (count_str.len == 0) continue;
            if (i >= num_shapes) break;
            counts[i] = try std.fmt.parseInt(usize, count_str, 10);
            i += 1;
        }
        
        try regions.append(.{
            .width = width,
            .height = height,
            .counts = counts,
        });
    }
    
    return regions;
}

fn rotateShape(allocator: std.mem.Allocator, shape: *const Shape) !Shape {
    var new_cells = std.ArrayList(Pos).init(allocator);
    const new_width: usize = shape.height;
    const new_height: usize = shape.width;
    
    for (shape.cells.items) |cell| {
        // Rotate 90 degrees clockwise: (x, y) -> (h-1-y, x)
        try new_cells.append(.{
            .x = @as(i32, @intCast(shape.height)) - 1 - cell.y,
            .y = cell.x,
        });
    }
    
    return Shape{
        .cells = new_cells,
        .width = new_width,
        .height = new_height,
    };
}

fn flipShape(allocator: std.mem.Allocator, shape: *const Shape) !Shape {
    var new_cells = std.ArrayList(Pos).init(allocator);
    
    for (shape.cells.items) |cell| {
        // Flip horizontally: (x, y) -> (w-1-x, y)
        try new_cells.append(.{
            .x = @as(i32, @intCast(shape.width)) - 1 - cell.x,
            .y = cell.y,
        });
    }
    
    return Shape{
        .cells = new_cells,
        .width = shape.width,
        .height = shape.height,
    };
}

fn shapesEqual(a: *const Shape, b: *const Shape) bool {
    if (a.width != b.width or a.height != b.height) return false;
    if (a.cells.items.len != b.cells.items.len) return false;
    
    for (a.cells.items) |cell_a| {
        var found = false;
        for (b.cells.items) |cell_b| {
            if (cell_a.x == cell_b.x and cell_a.y == cell_b.y) {
                found = true;
                break;
            }
        }
        if (!found) return false;
    }
    return true;
}

fn generateOrientations(allocator: std.mem.Allocator, shape: *const Shape) !std.ArrayList(Shape) {
    var orientations = std.ArrayList(Shape).init(allocator);
    
    var current = Shape{
        .cells = try shape.cells.clone(),
        .width = shape.width,
        .height = shape.height,
    };
    
    // Generate 4 rotations
    for (0..4) |_| {
        try orientations.append(.{
            .cells = try current.cells.clone(),
            .width = current.width,
            .height = current.height,
        });
        
        const next = try rotateShape(allocator, &current);
        current.deinit();
        current = next;
    }
    current.deinit();
    
    // Flip and generate 4 more rotations
    const flipped = try flipShape(allocator, shape);
    current = flipped;
    
    for (0..4) |_| {
        try orientations.append(.{
            .cells = try current.cells.clone(),
            .width = current.width,
            .height = current.height,
        });
        
        const next = try rotateShape(allocator, &current);
        current.deinit();
        current = next;
    }
    current.deinit();
    
    // Deduplicate orientations
    var unique = std.ArrayList(Shape).init(allocator);
    for (orientations.items) |*orientation| {
        var is_duplicate = false;
        for (unique.items) |*existing| {
            if (shapesEqual(orientation, existing)) {
                is_duplicate = true;
                break;
            }
        }
        if (!is_duplicate) {
            try unique.append(.{
                .cells = try orientation.cells.clone(),
                .width = orientation.width,
                .height = orientation.height,
            });
        }
    }
    
    for (orientations.items) |*orientation| {
        orientation.deinit();
    }
    orientations.deinit();
    
    return unique;
}

fn canPlaceShape(grid: [][]bool, shape: *const Shape, offset_x: i32, offset_y: i32, width: usize, height: usize) bool {
    for (shape.cells.items) |cell| {
        const x = cell.x + offset_x;
        const y = cell.y + offset_y;
        
        if (x < 0 or y < 0) return false;
        if (x >= @as(i32, @intCast(width)) or y >= @as(i32, @intCast(height))) return false;
        if (grid[@intCast(y)][@intCast(x)]) return false;
    }
    return true;
}

fn placeShape(grid: [][]bool, shape: *const Shape, offset_x: i32, offset_y: i32) void {
    for (shape.cells.items) |cell| {
        const x = cell.x + offset_x;
        const y = cell.y + offset_y;
        grid[@intCast(y)][@intCast(x)] = true;
    }
}

fn removeShape(grid: [][]bool, shape: *const Shape, offset_x: i32, offset_y: i32) void {
    for (shape.cells.items) |cell| {
        const x = cell.x + offset_x;
        const y = cell.y + offset_y;
        grid[@intCast(y)][@intCast(x)] = false;
    }
}

var search_counter: usize = 0;

fn tryFit(
    grid: [][]bool,
    all_orientations: []std.ArrayList(Shape),
    presents: []usize,
    index: usize,
    width: usize,
    height: usize,
) bool {
    if (index >= presents.len) {
        return true; // All presents placed successfully
    }
    
    const shape_idx = presents[index];
    const orientations = &all_orientations[shape_idx];
    
    // Progress reporting
    search_counter += 1;
    if (search_counter % 50000 == 0) {
        std.debug.print("Search depth {d}/{d}, attempts: {d}\n", .{index + 1, presents.len, search_counter});
    }
    
    // Try each orientation
    for (orientations.items) |*orientation| {
        // Try all positions
        for (0..height) |y| {
            for (0..width) |x| {
                const offset_x: i32 = @intCast(x);
                const offset_y: i32 = @intCast(y);
                
                if (canPlaceShape(grid, orientation, offset_x, offset_y, width, height)) {
                    placeShape(grid, orientation, offset_x, offset_y);
                    
                    if (tryFit(grid, all_orientations, presents, index + 1, width, height)) {
                        return true;
                    }
                    
                    removeShape(grid, orientation, offset_x, offset_y);
                }
            }
        }
    }
    
    return false;
}

fn canFitPresents(
    allocator: std.mem.Allocator,
    shapes: []const Shape,
    all_orientations: []std.ArrayList(Shape),
    region: *const Region,
) !bool {
    _ = shapes;
    
    // Create grid
    var grid = try allocator.alloc([]bool, region.height);
    defer {
        for (grid) |row| allocator.free(row);
        allocator.free(grid);
    }
    
    for (0..region.height) |i| {
        grid[i] = try allocator.alloc(bool, region.width);
        for (0..region.width) |j| {
            grid[i][j] = false;
        }
    }
    
    // Create list of presents to place
    var presents = std.ArrayList(usize).init(allocator);
    defer presents.deinit();
    
    for (region.counts, 0..) |count, shape_idx| {
        for (0..count) |_| {
            try presents.append(shape_idx);
        }
    }
    
    // Reset search counter for this region
    search_counter = 0;
    std.debug.print("\nTrying region {d}x{d} with {d} presents\n", .{region.width, region.height, presents.items.len});
    
    const result = tryFit(grid, all_orientations, presents.items, 0, region.width, region.height);
    std.debug.print("Result: {s}, total search attempts: {d}\n", .{if (result) "SUCCESS" else "FAILED", search_counter});
    
    return result;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const input = try std.io.getStdIn().readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(input);
    
    var shapes = try parseShapes(allocator, input);
    defer {
        for (shapes.items) |*shape| shape.deinit();
        shapes.deinit();
    }
    
    var regions = try parseRegions(allocator, input, shapes.items.len);
    defer {
        for (regions.items) |*region| region.deinit(allocator);
        regions.deinit();
    }
    
    // Generate all orientations for each shape
    var all_orientations = try allocator.alloc(std.ArrayList(Shape), shapes.items.len);
    defer {
        for (all_orientations) |*orientations| {
            for (orientations.items) |*shape| shape.deinit();
            orientations.deinit();
        }
        allocator.free(all_orientations);
    }
    
    for (shapes.items, 0..) |*shape, i| {
        all_orientations[i] = try generateOrientations(allocator, shape);
    }
    
    var count: usize = 0;
    for (regions.items) |*region| {
        if (try canFitPresents(allocator, shapes.items, all_orientations, region)) {
            count += 1;
        }
    }
    
    std.debug.print("{d}\n", .{count});
}
