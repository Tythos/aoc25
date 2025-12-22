const std = @import("std");
const utils = @import("utils");

/// Represents a button that affects specific counter positions
const Button = struct {
    positions: std.ArrayList(usize),

    fn deinit(self: *Button) void {
        self.positions.deinit();
    }
};

/// Represents a state as an array of counter values
const State = struct {
    counters: []u32,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, size: usize) !State {
        const counters = try allocator.alloc(u32, size);
        @memset(counters, 0);
        return State{
            .counters = counters,
            .allocator = allocator,
        };
    }

    fn initFromSlice(allocator: std.mem.Allocator, values: []const u32) !State {
        const counters = try allocator.alloc(u32, values.len);
        @memcpy(counters, values);
        return State{
            .counters = counters,
            .allocator = allocator,
        };
    }

    fn deinit(self: State) void {
        self.allocator.free(self.counters);
    }

    fn clone(self: State) !State {
        return initFromSlice(self.allocator, self.counters);
    }

    fn equals(self: State, other: State) bool {
        if (self.counters.len != other.counters.len) return false;
        for (self.counters, other.counters) |a, b| {
            if (a != b) return false;
        }
        return true;
    }

    fn hash(self: State) u64 {
        var hasher = std.hash.Wyhash.init(0);
        for (self.counters) |counter| {
            const bytes = std.mem.asBytes(&counter);
            hasher.update(bytes);
        }
        return hasher.final();
    }
};

/// Context for using State as a HashMap key
const StateContext = struct {
    pub fn hash(_: StateContext, key: State) u64 {
        return key.hash();
    }

    pub fn eql(_: StateContext, a: State, b: State) bool {
        return a.equals(b);
    }
};

/// Parses button configurations from a line
/// Reuses the same logic as part1
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

/// Parses joltage requirements from the {...} section
fn parseJoltageRequirements(allocator: std.mem.Allocator, line: []const u8) !std.ArrayList(u32) {
    var requirements = std.ArrayList(u32).init(allocator);
    
    // Find the region between '{' and '}'
    const start_brace = std.mem.indexOf(u8, line, "{") orelse return requirements;
    const end_brace = std.mem.indexOf(u8, line, "}") orelse return requirements;
    
    if (start_brace >= end_brace) return requirements;
    
    const region = line[start_brace + 1 .. end_brace];
    
    // Parse comma-separated numbers
    var iter = std.mem.splitSequence(u8, region, ",");
    while (iter.next()) |num_str| {
        const trimmed = std.mem.trim(u8, num_str, " \t");
        if (trimmed.len > 0) {
            const num = try std.fmt.parseInt(u32, trimmed, 10);
            try requirements.append(num);
        }
    }
    
    return requirements;
}

/// Frees memory used by buttons
fn freeButtons(buttons: std.ArrayList(Button)) void {
    for (buttons.items) |*button| {
        button.deinit();
    }
    buttons.deinit();
}

/// Applies a button press to state counters, returning new state
/// Increments counters at the button's positions
fn applyButton(_: std.mem.Allocator, state: State, button: Button) !State {
    var new_state = try state.clone();
    for (button.positions.items) |pos| {
        if (pos < new_state.counters.len) {
            new_state.counters[pos] += 1;
        }
    }
    return new_state;
}

/// Checks if state is valid (no counter exceeds its target)
fn isValidState(state: State, target: []const u32) bool {
    if (state.counters.len != target.len) return false;
    for (state.counters, target) |counter, target_val| {
        if (counter > target_val) return false;
    }
    return true;
}

/// Hash function for state arrays
fn hashState(state: []const u32) u64 {
    var hasher = std.hash.Wyhash.init(0);
    const bytes = std.mem.sliceAsBytes(state);
    hasher.update(bytes);
    return hasher.final();
}

/// Equality check for state arrays
fn statesEqual(a: []const u32, b: []const u32) bool {
    if (a.len != b.len) return false;
    for (a, b) |av, bv| {
        if (av != bv) return false;
    }
    return true;
}

const StateMap = struct {
    const Bucket = struct {
        keys: std.ArrayList([]u32),
        values: std.ArrayList(u32),
    };

    buckets: []Bucket,
    allocator: std.mem.Allocator,
    num_buckets: usize,

    fn init(allocator: std.mem.Allocator) !StateMap {
        const num_buckets: usize = 1024;
        const buckets = try allocator.alloc(Bucket, num_buckets);
        for (buckets) |*bucket| {
            bucket.* = .{
                .keys = std.ArrayList([]u32).init(allocator),
                .values = std.ArrayList(u32).init(allocator),
            };
        }
        return .{
            .buckets = buckets,
            .allocator = allocator,
            .num_buckets = num_buckets,
        };
    }

    fn deinit(self: *StateMap) void {
        for (self.buckets) |*bucket| {
            for (bucket.keys.items) |key| {
                self.allocator.free(key);
            }
            bucket.keys.deinit();
            bucket.values.deinit();
        }
        self.allocator.free(self.buckets);
    }

    fn getBucket(self: *const StateMap, state: []const u32) usize {
        const hash_val = hashState(state);
        return hash_val % self.num_buckets;
    }

    fn get(self: *const StateMap, state: []const u32) ?u32 {
        const bucket_idx = self.getBucket(state);
        const bucket = &self.buckets[bucket_idx];
        for (bucket.keys.items, bucket.values.items) |key, val| {
            if (statesEqual(key, state)) return val;
        }
        return null;
    }

    fn put(self: *StateMap, state: []const u32, value: u32) !void {
        const bucket_idx = self.getBucket(state);
        var bucket = &self.buckets[bucket_idx];
        
        // Check if already exists in this bucket
        for (bucket.keys.items, 0..) |key, i| {
            if (statesEqual(key, state)) {
                bucket.values.items[i] = value;
                return;
            }
        }
        
        // Add new entry to bucket
        const key_copy = try self.allocator.alloc(u32, state.len);
        @memcpy(key_copy, state);
        try bucket.keys.append(key_copy);
        try bucket.values.append(value);
    }

    fn contains(self: *const StateMap, state: []const u32) bool {
        return self.get(state) != null;
    }
};

/// BFS to find shortest path from start to target  
fn findShortestPath(
    allocator: std.mem.Allocator,
    buttons: []const Button,
    target: []const u32,
) !u32 {
    // Check if already at target (all zeros)
    var at_target = true;
    for (target) |val| {
        if (val != 0) {
            at_target = false;
            break;
        }
    }
    if (at_target) return 0;

    // BFS queue - store states as arrays
    var queue = std.ArrayList([]u32).init(allocator);
    defer {
        for (queue.items) |state| {
            allocator.free(state);
        }
        queue.deinit();
    }
    
    const start_state = try allocator.alloc(u32, target.len);
    @memset(start_state, 0);
    try queue.append(start_state);

    // Visited set
    var visited = try StateMap.init(allocator);
    defer visited.deinit();
    try visited.put(start_state, 0);

    // Distance tracking
    var distances = try StateMap.init(allocator);
    defer distances.deinit();
    try distances.put(start_state, 0);

    var queue_index: usize = 0;

    // BFS loop
    while (queue_index < queue.items.len) : (queue_index += 1) {
        const current = queue.items[queue_index];
        const current_dist = distances.get(current).?;

        // Check if we reached target - BFS guarantees first solution is optimal
        if (statesEqual(current, target)) {
            return current_dist;
        }

        // Explore all buttons
        for (buttons) |button| {
            // Apply button to new state
            const next_state = try allocator.alloc(u32, current.len);
            @memcpy(next_state, current);
            
            for (button.positions.items) |pos| {
                if (pos < next_state.len) {
                    next_state[pos] += 1;
                }
            }
            
            // Check if state is valid (no counter exceeds target)
            var valid = true;
            for (next_state, target) |counter, target_val| {
                if (counter > target_val) {
                    valid = false;
                    break;
                }
            }
            
            if (!valid) {
                allocator.free(next_state);
                continue;
            }

            // Check if already visited
            if (!visited.contains(next_state)) {
                try visited.put(next_state, 0);
                try distances.put(next_state, current_dist + 1);
                try queue.append(next_state);
            } else {
                allocator.free(next_state);
            }
        }
    }

    // Should never reach here if puzzle has solution
    return 0;
}

fn solve_line(allocator: std.mem.Allocator, line: []const u8) !u32 {
    // Parse button configurations
    const buttons = try parseButtons(allocator, line);
    defer freeButtons(buttons);
    
    // Parse joltage requirements (target)
    const target_list = try parseJoltageRequirements(allocator, line);
    defer target_list.deinit();
    
    if (target_list.items.len == 0) return 0;
    
    // Find shortest path using BFS
    const min_presses = try findShortestPath(allocator, buttons.items, target_list.items);
    
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
    var line_num: usize = 0;
    for (lines.items) |line| {
        if (line.len == 0) continue;
        line_num += 1;
        
        const start_time = std.time.milliTimestamp();
        const presses = try solve_line(allocator, line);
        const elapsed_ms = std.time.milliTimestamp() - start_time;
        
        std.debug.print("Line {d}: solution={d} depth={d} time={d}ms\n", .{line_num, presses, presses, elapsed_ms});
        total_presses += presses;
    }
    std.debug.print("\ntotal presses: {}\n", .{total_presses});
}

test "parseJoltageRequirements" {
    const allocator = std.testing.allocator;
    
    const line = "[.##.] (3) (1,3) {3,5,4,7}";
    const requirements = try parseJoltageRequirements(allocator, line);
    defer requirements.deinit();
    
    try std.testing.expectEqual(@as(usize, 4), requirements.items.len);
    try std.testing.expectEqual(@as(u32, 3), requirements.items[0]);
    try std.testing.expectEqual(@as(u32, 5), requirements.items[1]);
    try std.testing.expectEqual(@as(u32, 4), requirements.items[2]);
    try std.testing.expectEqual(@as(u32, 7), requirements.items[3]);
}

test "State equals and hash" {
    const allocator = std.testing.allocator;
    
    const state1 = try State.initFromSlice(allocator, &[_]u32{ 1, 2, 3 });
    defer state1.deinit();
    
    const state2 = try State.initFromSlice(allocator, &[_]u32{ 1, 2, 3 });
    defer state2.deinit();
    
    const state3 = try State.initFromSlice(allocator, &[_]u32{ 1, 2, 4 });
    defer state3.deinit();
    
    try std.testing.expect(state1.equals(state2));
    try std.testing.expect(!state1.equals(state3));
    try std.testing.expectEqual(state1.hash(), state2.hash());
}

test "applyButton increments counters" {
    const allocator = std.testing.allocator;
    
    var button = Button{ .positions = std.ArrayList(usize).init(allocator) };
    defer button.deinit();
    try button.positions.append(1);
    try button.positions.append(3);
    
    const state = try State.initFromSlice(allocator, &[_]u32{ 0, 1, 2, 3 });
    defer state.deinit();
    
    const new_state = try applyButton(allocator, state, button);
    defer new_state.deinit();
    
    try std.testing.expectEqual(@as(u32, 0), new_state.counters[0]);
    try std.testing.expectEqual(@as(u32, 2), new_state.counters[1]);
    try std.testing.expectEqual(@as(u32, 2), new_state.counters[2]);
    try std.testing.expectEqual(@as(u32, 4), new_state.counters[3]);
}

test "isValidState" {
    const allocator = std.testing.allocator;
    
    const target = [_]u32{ 3, 5, 4, 7 };
    
    const valid_state = try State.initFromSlice(allocator, &[_]u32{ 2, 4, 3, 6 });
    defer valid_state.deinit();
    try std.testing.expect(isValidState(valid_state, &target));
    
    const exact_state = try State.initFromSlice(allocator, &target);
    defer exact_state.deinit();
    try std.testing.expect(isValidState(exact_state, &target));
    
    const invalid_state = try State.initFromSlice(allocator, &[_]u32{ 3, 6, 4, 7 });
    defer invalid_state.deinit();
    try std.testing.expect(!isValidState(invalid_state, &target));
}

test "solve_line with test data line 1" {
    const allocator = std.testing.allocator;
    
    const line = "[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}";
    const result = try solve_line(allocator, line);
    
    // Expected: 10 button presses
    try std.testing.expectEqual(@as(u32, 10), result);
}

test "solve_line with test data line 2" {
    const allocator = std.testing.allocator;
    
    const line = "[...#.] (0,2,3,4) (2,3) (0,4) (0,1,2) (1,2,3,4) {7,5,12,7,2}";
    const result = try solve_line(allocator, line);
    
    // Expected: 12 button presses
    try std.testing.expectEqual(@as(u32, 12), result);
}

test "solve_line with test data line 3" {
    const allocator = std.testing.allocator;
    
    const line = "[.###.#] (0,1,2,3,4) (0,3,4) (0,1,2,4,5) (1,2) {10,11,11,5,10,5}";
    const result = try solve_line(allocator, line);
    
    // Expected: 11 button presses
    try std.testing.expectEqual(@as(u32, 11), result);
}
