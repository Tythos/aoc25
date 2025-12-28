const std = @import("std");
const utils = @import("utils");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Read input from stdin
    const stdin = try utils.read_from_stdin(allocator);
    defer allocator.free(stdin);
    
    // Build graph: map node names to indices and store edges
    var node_map = std.StringHashMap(usize).init(allocator);
    defer node_map.deinit();
    var node_names = std.ArrayList([]u8).init(allocator);
    defer {
        for (node_names.items) |name| {
            allocator.free(name);
        }
        node_names.deinit();
    }
    var edges = std.ArrayList(struct { usize, usize }).init(allocator);
    defer edges.deinit();
    
    var next_id: usize = 0;
    
    // Helper to get or create node index
    const getNodeIndex = struct {
        fn call(
            alloc: std.mem.Allocator,
            map: *std.StringHashMap(usize),
            names: *std.ArrayList([]u8),
            next: *usize,
            name: []const u8,
        ) !usize {
            if (map.get(name)) |idx| {
                return idx;
            }
            const name_copy = try alloc.dupe(u8, name);
            const idx = next.*;
            try map.put(name_copy, idx);
            try names.append(name_copy);
            next.* += 1;
            return idx;
        }
    }.call;
    
    // Parse input
    var lines_iter = std.mem.splitScalar(u8, stdin, '\n');
    while (lines_iter.next()) |line| {
        if (line.len == 0) continue;
        
        const colon_pos = std.mem.indexOf(u8, line, ":") orelse continue;
        const from_name = utils.strip_string(line[0..colon_pos]);
        const from_idx = try getNodeIndex(allocator, &node_map, &node_names, &next_id, from_name);
        
        const rest = utils.strip_string(line[colon_pos + 1..]);
        var dest_iter = std.mem.splitScalar(u8, rest, ' ');
        while (dest_iter.next()) |to_name| {
            if (to_name.len == 0) continue;
            const to_idx = try getNodeIndex(allocator, &node_map, &node_names, &next_id, to_name);
            try edges.append(.{ from_idx, to_idx });
        }
    }
    
    // Find start and end nodes
    const you_idx = node_map.get("you") orelse {
        std.debug.print("Error: 'you' node not found\n", .{});
        return;
    };
    const out_idx = node_map.get("out") orelse {
        std.debug.print("Error: 'out' node not found\n", .{});
        return;
    };
    
    // Build adjacency list
    var adj_list = try allocator.alloc(std.ArrayList(usize), node_names.items.len);
    defer {
        for (adj_list) |*list| {
            list.deinit();
        }
        allocator.free(adj_list);
    }
    for (adj_list) |*list| {
        list.* = std.ArrayList(usize).init(allocator);
    }
    for (edges.items) |edge| {
        try adj_list[edge[0]].append(edge[1]);
    }
    
    // Count paths using DFS
    var path_count: usize = 0;
    var stack = std.ArrayList(usize).init(allocator);
    defer stack.deinit();
    
    try stack.append(you_idx);
    while (stack.items.len > 0) {
        const current = stack.pop();
        if (current == out_idx) {
            path_count += 1;
            continue;
        }
        for (adj_list[current].items) |neighbor| {
            try stack.append(neighbor);
        }
    }
    
    std.debug.print("{}\n", .{path_count});
}
