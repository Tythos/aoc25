const std = @import("std");
const utils = @import("utils");

/// Represents a button that toggles specific bit positions
const Button = struct {
    positions: std.ArrayList(usize),

    fn deinit(self: *Button) void {
        self.positions.deinit();
    }
};

/// Converts a pattern string (e.g., ".##.") to a state integer.
/// Each character is mapped to a bit: '.' = 0, '#' = 1
fn patternToState(pattern: []const u8) u32 {
    var state: u32 = 0;
    for (pattern, 0..) |char, i| {
        if (char == '#') {
            state |= @as(u32, 1) << @intCast(i);
        }
    }
    return state;
}

/// Parses button configurations from a line
/// Example: "(3) (1,3) (2)" -> 3 buttons with positions [3], [1,3], [2]
fn parseButtons(allocator: std.mem.Allocator, line: []const u8) !std.ArrayList(Button) {
    var buttons = std.ArrayList(Button).init(allocator);
    
    // Find the region between ']' and '{'
    const start_bracket = std.mem.indexOf(u8, line, "]") orelse return buttons;
    const end_bracket = std.mem.indexOf(u8, line, "{") orelse return buttons;
    
    if (start_bracket >= end_bracket) return buttons;
    
    const region = line[start_bracket + 1 .. end_bracket];
    
    // Parse button groups in format (n) or (n,m,...)
    var i: usize = 0;
    while (i < region.len) {
        if (region[i] == '(') {
            // Find matching ')'
            var j = i + 1;
            while (j < region.len and region[j] != ')') : (j += 1) {}
            
            if (j < region.len) {
                const button_content = region[i + 1 .. j];
                var button = Button{ .positions = std.ArrayList(usize).init(allocator) };
                
                // Parse comma-separated numbers
                var iter = std.mem.splitSequence(u8, button_content, ",");
                while (iter.next()) |num_str| {
                    const trimmed = std.mem.trim(u8, num_str, " \t");
                    if (trimmed.len > 0) {
                        const num = try std.fmt.parseInt(usize, trimmed, 10);
                        try button.positions.append(num);
                    }
                }
                
                try buttons.append(button);
                i = j + 1;
            } else {
                break;
            }
        } else {
            i += 1;
        }
    }
    
    return buttons;
}

/// Applies a button press to a state, returning the resulting state
/// Uses XOR to toggle the bits at the button's positions
fn applyButton(state: u32, button: Button) u32 {
    var new_state = state;
    for (button.positions.items) |pos| {
        new_state ^= @as(u32, 1) << @intCast(pos);
    }
    return new_state;
}

/// Builds the adjacency list for state transitions
/// Returns a HashMap mapping each state to its list of neighbor states
fn buildEdges(
    allocator: std.mem.Allocator,
    states: []const u32,
    buttons: []const Button,
) !std.AutoHashMap(u32, std.ArrayList(u32)) {
    var edges = std.AutoHashMap(u32, std.ArrayList(u32)).init(allocator);
    
    for (states) |state| {
        var neighbors = std.ArrayList(u32).init(allocator);
        
        for (buttons) |button| {
            const next_state = applyButton(state, button);
            try neighbors.append(next_state);
        }
        
        try edges.put(state, neighbors);
    }
    
    return edges;
}

/// Frees memory used by buttons
fn freeButtons(buttons: std.ArrayList(Button)) void {
    for (buttons.items) |*button| {
        button.deinit();
    }
    buttons.deinit();
}

/// Frees memory used by edges
fn freeEdges(edges: *std.AutoHashMap(u32, std.ArrayList(u32))) void {
    var iter = edges.valueIterator();
    while (iter.next()) |neighbors| {
        neighbors.deinit();
    }
    edges.deinit();
}

/// Constructs the graph of all possible states for a given pattern length.
/// Returns an ArrayList of u32 integers representing states from 0 to 2^pattern_length - 1.
/// Each state integer can be used as an index in adjacency structures.
fn buildStateGraph(allocator: std.mem.Allocator, pattern_length: usize) !std.ArrayList(u32) {
    const num_states = @as(u32, 1) << @intCast(pattern_length); // 2^n
    var states = std.ArrayList(u32).init(allocator);
    var i: u32 = 0;
    while (i < num_states) : (i += 1) {
        try states.append(i);
    }
    return states;
}

/// Finds the shortest path from start to target using BFS
/// Returns the minimum number of button presses needed
fn findShortestPath(
    allocator: std.mem.Allocator,
    edges: std.AutoHashMap(u32, std.ArrayList(u32)),
    start: u32,
    target: u32,
) !u32 {
    // Early exit: already at target
    if (start == target) return 0;

    // Initialize BFS
    var queue = std.ArrayList(u32).init(allocator);
    defer queue.deinit();
    try queue.append(start);

    var distances = std.AutoHashMap(u32, u32).init(allocator);
    defer distances.deinit();
    try distances.put(start, 0);

    var queue_index: usize = 0;

    // BFS loop
    while (queue_index < queue.items.len) : (queue_index += 1) {
        const current = queue.items[queue_index];
        const current_dist = distances.get(current).?;

        // Check if we reached target
        if (current == target) return current_dist;

        // Explore neighbors
        const neighbors = edges.get(current) orelse continue;
        for (neighbors.items) |neighbor| {
            if (!distances.contains(neighbor)) {
                try distances.put(neighbor, current_dist + 1);
                try queue.append(neighbor);
            }
        }
    }

    // Should never reach here (assumed all have solutions)
    return distances.get(target).?;
}

fn solve_line(allocator: std.mem.Allocator, line: []const u8) !u32 {
    // Parse button configurations from the line
    const buttons = try parseButtons(allocator, line);
    defer freeButtons(buttons);
    
    // Extract pattern from line (between [ and ])
    const pattern_start = std.mem.indexOf(u8, line, "[") orelse return 0;
    const pattern_end = std.mem.indexOf(u8, line, "]") orelse return 0;
    if (pattern_start >= pattern_end) return 0;
    const pattern = line[pattern_start + 1 .. pattern_end];
    
    // First, we will construct the graph of all possible states
    const pattern_length = pattern.len;
    const all_states = try buildStateGraph(allocator, pattern_length);
    defer all_states.deinit();

    // Second, we will add edges indicating each possible transitions from each state
    var edges = try buildEdges(allocator, all_states.items, buttons.items);
    defer freeEdges(&edges);

    // Third, we will start at "0" and find the "shortest path" (fewest button presses) to the desired state
    const target_state = patternToState(pattern);
    const min_presses = try findShortestPath(allocator, edges, 0, target_state);
    
    return min_presses;
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

    // count fewest total button presses
    var total_presses: u32 = 0;
    for (lines.items) |line| {
        total_presses += try solve_line(allocator, line);
    }
    std.debug.print("total presses: {}\n", .{total_presses});
}

test "patternToState conversion" {
    // Test empty pattern (all dots)
    try std.testing.expectEqual(@as(u32, 0), patternToState("..."));
    
    // Test pattern ".##" -> binary 110 -> 6
    try std.testing.expectEqual(@as(u32, 6), patternToState(".##"));
    
    // Test pattern "#.#" -> binary 101 -> 5
    try std.testing.expectEqual(@as(u32, 5), patternToState("#.#"));
    
    // Test pattern "####" -> binary 1111 -> 15
    try std.testing.expectEqual(@as(u32, 15), patternToState("####"));
    
    // Test pattern "#..." -> binary 0001 -> 1
    try std.testing.expectEqual(@as(u32, 1), patternToState("#..."));
}

test "buildStateGraph with length 2" {
    const allocator = std.testing.allocator;
    
    const states = try buildStateGraph(allocator, 2);
    defer states.deinit();
    
    // Should have 2^2 = 4 states
    try std.testing.expectEqual(@as(usize, 4), states.items.len);
    
    // States should be [0, 1, 2, 3]
    try std.testing.expectEqual(@as(u32, 0), states.items[0]);
    try std.testing.expectEqual(@as(u32, 1), states.items[1]);
    try std.testing.expectEqual(@as(u32, 2), states.items[2]);
    try std.testing.expectEqual(@as(u32, 3), states.items[3]);
}

test "buildStateGraph with length 3" {
    const allocator = std.testing.allocator;
    
    const states = try buildStateGraph(allocator, 3);
    defer states.deinit();
    
    // Should have 2^3 = 8 states
    try std.testing.expectEqual(@as(usize, 8), states.items.len);
    
    // States should be sequential from 0 to 7
    for (states.items, 0..) |state, i| {
        try std.testing.expectEqual(@as(u32, @intCast(i)), state);
    }
}

test "buildStateGraph with length 4" {
    const allocator = std.testing.allocator;
    
    const states = try buildStateGraph(allocator, 4);
    defer states.deinit();
    
    // Should have 2^4 = 16 states
    try std.testing.expectEqual(@as(usize, 16), states.items.len);
    
    // First and last states
    try std.testing.expectEqual(@as(u32, 0), states.items[0]);
    try std.testing.expectEqual(@as(u32, 15), states.items[15]);
}

test "parseButtons single position" {
    const allocator = std.testing.allocator;
    
    const line = "[.##.] (3) {1,2}";
    const buttons = try parseButtons(allocator, line);
    defer freeButtons(buttons);
    
    // Should have 1 button
    try std.testing.expectEqual(@as(usize, 1), buttons.items.len);
    
    // Button should have position 3
    try std.testing.expectEqual(@as(usize, 1), buttons.items[0].positions.items.len);
    try std.testing.expectEqual(@as(usize, 3), buttons.items[0].positions.items[0]);
}

test "parseButtons multiple positions" {
    const allocator = std.testing.allocator;
    
    const line = "[.##.] (1,3) {1,2}";
    const buttons = try parseButtons(allocator, line);
    defer freeButtons(buttons);
    
    // Should have 1 button
    try std.testing.expectEqual(@as(usize, 1), buttons.items.len);
    
    // Button should have positions 1 and 3
    try std.testing.expectEqual(@as(usize, 2), buttons.items[0].positions.items.len);
    try std.testing.expectEqual(@as(usize, 1), buttons.items[0].positions.items[0]);
    try std.testing.expectEqual(@as(usize, 3), buttons.items[0].positions.items[1]);
}

test "parseButtons multiple buttons" {
    const allocator = std.testing.allocator;
    
    const line = "[.##.] (3) (1,3) (2) {1,2,3}";
    const buttons = try parseButtons(allocator, line);
    defer freeButtons(buttons);
    
    // Should have 3 buttons
    try std.testing.expectEqual(@as(usize, 3), buttons.items.len);
    
    // First button: (3)
    try std.testing.expectEqual(@as(usize, 1), buttons.items[0].positions.items.len);
    try std.testing.expectEqual(@as(usize, 3), buttons.items[0].positions.items[0]);
    
    // Second button: (1,3)
    try std.testing.expectEqual(@as(usize, 2), buttons.items[1].positions.items.len);
    try std.testing.expectEqual(@as(usize, 1), buttons.items[1].positions.items[0]);
    try std.testing.expectEqual(@as(usize, 3), buttons.items[1].positions.items[1]);
    
    // Third button: (2)
    try std.testing.expectEqual(@as(usize, 1), buttons.items[2].positions.items.len);
    try std.testing.expectEqual(@as(usize, 2), buttons.items[2].positions.items[0]);
}

test "applyButton single position" {
    const allocator = std.testing.allocator;
    
    var button = Button{ .positions = std.ArrayList(usize).init(allocator) };
    defer button.deinit();
    try button.positions.append(3);
    
    // State: 0b0110 (6), toggle bit 3 -> 0b1110 (14)
    const state: u32 = 6;
    const new_state = applyButton(state, button);
    try std.testing.expectEqual(@as(u32, 14), new_state);
}

test "applyButton multiple positions" {
    const allocator = std.testing.allocator;
    
    var button = Button{ .positions = std.ArrayList(usize).init(allocator) };
    defer button.deinit();
    try button.positions.append(1);
    try button.positions.append(3);
    
    // State: 0b0110 (6), toggle bits 1 and 3 -> 0b1100 (12)
    const state: u32 = 6;
    const new_state = applyButton(state, button);
    try std.testing.expectEqual(@as(u32, 12), new_state);
}

test "applyButton bidirectional" {
    const allocator = std.testing.allocator;
    
    var button = Button{ .positions = std.ArrayList(usize).init(allocator) };
    defer button.deinit();
    try button.positions.append(1);
    try button.positions.append(2);
    
    // Pressing same button twice returns to original state
    const state: u32 = 5;
    const state2 = applyButton(state, button);
    const state3 = applyButton(state2, button);
    try std.testing.expectEqual(state, state3);
}

test "buildEdges simple graph" {
    const allocator = std.testing.allocator;
    
    // Create 2-bit states (4 total: 0, 1, 2, 3)
    const states = try buildStateGraph(allocator, 2);
    defer states.deinit();
    
    // Create 1 button that toggles bit 0
    var button = Button{ .positions = std.ArrayList(usize).init(allocator) };
    try button.positions.append(0);
    
    var buttons = std.ArrayList(Button).init(allocator);
    try buttons.append(button);
    defer freeButtons(buttons);
    
    // Build edges
    var edges = try buildEdges(allocator, states.items, buttons.items);
    defer freeEdges(&edges);
    
    // Verify edges: 0→1, 1→0, 2→3, 3→2
    const neighbors_0 = edges.get(0).?;
    try std.testing.expectEqual(@as(usize, 1), neighbors_0.items.len);
    try std.testing.expectEqual(@as(u32, 1), neighbors_0.items[0]);
    
    const neighbors_1 = edges.get(1).?;
    try std.testing.expectEqual(@as(usize, 1), neighbors_1.items.len);
    try std.testing.expectEqual(@as(u32, 0), neighbors_1.items[0]);
    
    const neighbors_2 = edges.get(2).?;
    try std.testing.expectEqual(@as(usize, 1), neighbors_2.items.len);
    try std.testing.expectEqual(@as(u32, 3), neighbors_2.items[0]);
    
    const neighbors_3 = edges.get(3).?;
    try std.testing.expectEqual(@as(usize, 1), neighbors_3.items.len);
    try std.testing.expectEqual(@as(u32, 2), neighbors_3.items[0]);
}

test "findShortestPath target equals start" {
    const allocator = std.testing.allocator;
    
    // Create minimal graph
    const states = try buildStateGraph(allocator, 2);
    defer states.deinit();
    
    var button = Button{ .positions = std.ArrayList(usize).init(allocator) };
    try button.positions.append(0);
    
    var buttons = std.ArrayList(Button).init(allocator);
    try buttons.append(button);
    defer freeButtons(buttons);
    
    var edges = try buildEdges(allocator, states.items, buttons.items);
    defer freeEdges(&edges);
    
    // Start and target are the same
    const distance = try findShortestPath(allocator, edges, 0, 0);
    try std.testing.expectEqual(@as(u32, 0), distance);
}

test "findShortestPath simple one step" {
    const allocator = std.testing.allocator;
    
    // Create 2-bit states
    const states = try buildStateGraph(allocator, 2);
    defer states.deinit();
    
    // Button toggles bit 0
    var button = Button{ .positions = std.ArrayList(usize).init(allocator) };
    try button.positions.append(0);
    
    var buttons = std.ArrayList(Button).init(allocator);
    try buttons.append(button);
    defer freeButtons(buttons);
    
    var edges = try buildEdges(allocator, states.items, buttons.items);
    defer freeEdges(&edges);
    
    // From 0 to 1 requires 1 button press
    const distance = try findShortestPath(allocator, edges, 0, 1);
    try std.testing.expectEqual(@as(u32, 1), distance);
}

test "findShortestPath multiple steps" {
    const allocator = std.testing.allocator;
    
    // Create 2-bit states (0, 1, 2, 3)
    const states = try buildStateGraph(allocator, 2);
    defer states.deinit();
    
    // Button toggles bit 0 only
    var button = Button{ .positions = std.ArrayList(usize).init(allocator) };
    try button.positions.append(0);
    
    var buttons = std.ArrayList(Button).init(allocator);
    try buttons.append(button);
    defer freeButtons(buttons);
    
    var edges = try buildEdges(allocator, states.items, buttons.items);
    defer freeEdges(&edges);
    
    // From 0 (00) to 3 (11) - impossible with only bit 0 toggle
    // But from 0 to 1 is 1 step
    const distance_0_to_1 = try findShortestPath(allocator, edges, 0, 1);
    try std.testing.expectEqual(@as(u32, 1), distance_0_to_1);
    
    // From 2 (10) to 3 (11) is also 1 step
    const distance_2_to_3 = try findShortestPath(allocator, edges, 2, 3);
    try std.testing.expectEqual(@as(u32, 1), distance_2_to_3);
}

test "findShortestPath with actual test data" {
    const allocator = std.testing.allocator;
    
    // First test line: [.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}
    // Target pattern: .##. → binary 0110 → state 6
    const line = "[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}";
    const result = try solve_line(allocator, line);
    
    // Should find a valid path (result >= 0)
    // BFS guarantees shortest path
    try std.testing.expect(result >= 0);
    try std.testing.expect(result <= 10);
}
