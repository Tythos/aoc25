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

    // For part 2, we need to track the NUMBER of timelines at each position
    // Multiple timelines can be at the same position
    // When a timeline hits a splitter, it splits into 2 timelines (one goes left, one goes right)
    
    const width = lines.items[0].len;
    const height = lines.items.len;
    
    // Track timeline counts at each position for current and previous row
    var prev_counts = try allocator.alloc(u64, width);
    defer allocator.free(prev_counts);
    var curr_counts = try allocator.alloc(u64, width);
    defer allocator.free(curr_counts);
    
    // Initialize all counts to 0
    for (prev_counts) |*count| count.* = 0;
    for (curr_counts) |*count| count.* = 0;
    
    // Find starting position and initialize with 1 timeline
    for (lines.items[0], 0..) |c, col| {
        if (c == 'S') {
            prev_counts[col] = 1;
            break;
        }
    }
    
    // Process each row
    for (1..height) |row| {
        const current_line = lines.items[row];
        const previous_line = lines.items[row - 1];
        
        // Reset current counts
        for (curr_counts) |*count| count.* = 0;
        
        // Process each column
        for (current_line, 0..) |c, col| {
            if (c == '.') {
                // Check if timeline(s) come from above (beam continuing straight down)
                if (prev_counts[col] > 0 and (previous_line[col] == 'S' or previous_line[col] == '.')) {
                    curr_counts[col] += prev_counts[col];
                }
                // Check if timeline(s) come from adjacent splitter (left)
                if (col > 0 and current_line[col-1] == '^' and prev_counts[col-1] > 0) {
                    curr_counts[col] += prev_counts[col-1];
                }
                // Check if timeline(s) come from adjacent splitter (right)
                if (col + 1 < width and current_line[col+1] == '^' and prev_counts[col+1] > 0) {
                    curr_counts[col] += prev_counts[col+1];
                }
            } else if (c == '^') {
                // Splitter position - timelines continue through
                if (prev_counts[col] > 0) {
                    curr_counts[col] = prev_counts[col];
                }
            }
        }
        
        // Swap arrays
        const temp = prev_counts;
        prev_counts = curr_counts;
        curr_counts = temp;
    }
    
    // Count total timelines at the final row
    var total_timelines: u64 = 0;
    for (prev_counts) |count| {
        total_timelines += count;
    }
    
    std.debug.print("total number of pathways: {}\n", .{total_timelines});
}
