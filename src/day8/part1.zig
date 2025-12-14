const std = @import("std");
const utils = @import("utils");

const XYZ = struct {
    x: i32,
    y: i32,
    z: i32,

    pub fn from_string(allocator: std.mem.Allocator, string: []const u8) !XYZ {
        const parts = try utils.split_string_by_delimiter(allocator, string, ",");
        defer utils.free_string_list(allocator, parts);
        return XYZ{
            .x = std.fmt.parseInt(i32, parts.items[0], 10) catch return error.InvalidXYZ,
            .y = std.fmt.parseInt(i32, parts.items[1], 10) catch return error.InvalidXYZ,
            .z = std.fmt.parseInt(i32, parts.items[2], 10) catch return error.InvalidXYZ,
        };
    }

    pub fn squared_distance(self: XYZ, other: XYZ) i64 {
        const dx: i64 = @as(i64, self.x) - @as(i64, other.x);
        const dy: i64 = @as(i64, self.y) - @as(i64, other.y);
        const dz: i64 = @as(i64, self.z) - @as(i64, other.z);
        return dx * dx + dy * dy + dz * dz;
    }
};

const Edge = struct {
    i: usize,
    j: usize,
    dist: i64,
};

fn edge_less_than(_: void, a: Edge, b: Edge) bool {
    return a.dist < b.dist;
}

// Union-Find data structure
const UnionFind = struct {
    parent: []usize,
    rank: []usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, n: usize) !UnionFind {
        const parent = try allocator.alloc(usize, n);
        const rank = try allocator.alloc(usize, n);
        for (0..n) |i| {
            parent[i] = i;
            rank[i] = 0;
        }
        return UnionFind{
            .parent = parent,
            .rank = rank,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *UnionFind) void {
        self.allocator.free(self.parent);
        self.allocator.free(self.rank);
    }

    pub fn find(self: *UnionFind, x: usize) usize {
        if (self.parent[x] != x) {
            self.parent[x] = self.find(self.parent[x]); // path compression
        }
        return self.parent[x];
    }

    pub fn unite(self: *UnionFind, x: usize, y: usize) bool {
        const root_x = self.find(x);
        const root_y = self.find(y);
        
        if (root_x == root_y) {
            return false; // already connected
        }

        // union by rank
        if (self.rank[root_x] < self.rank[root_y]) {
            self.parent[root_x] = root_y;
        } else if (self.rank[root_x] > self.rank[root_y]) {
            self.parent[root_y] = root_x;
        } else {
            self.parent[root_y] = root_x;
            self.rank[root_x] += 1;
        }
        return true;
    }
};

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

    // parse all coordinates
    var coords = std.ArrayList(XYZ).init(allocator);
    defer coords.deinit();
    for (lines.items) |line| {
        if (line.len > 0) {
            const xyz = try XYZ.from_string(allocator, line);
            try coords.append(xyz);
        }
    }

    const n = coords.items.len;
    std.debug.print("Parsed {d} junction boxes\n", .{n});

    // calculate all pairwise distances
    var edges = std.ArrayList(Edge).init(allocator);
    defer edges.deinit();
    
    for (0..n) |i| {
        for (i + 1..n) |j| {
            const dist = coords.items[i].squared_distance(coords.items[j]);
            try edges.append(Edge{ .i = i, .j = j, .dist = dist });
        }
    }

    // sort edges by distance
    std.mem.sort(Edge, edges.items, {}, edge_less_than);
    
    std.debug.print("Total edges: {d}\n", .{edges.items.len});

    // connect the closest pairs using Union-Find
    // For test input (20 boxes), use 10 connections; for larger inputs, use 1000
    var uf = try UnionFind.init(allocator, n);
    defer uf.deinit();

    const max_connections: usize = if (n <= 20) 10 else 1000;
    var connections_attempted: usize = 0;
    var connections_successful: usize = 0;
    
    for (edges.items) |edge| {
        if (connections_attempted >= max_connections) {
            break;
        }
        connections_attempted += 1;
        if (uf.unite(edge.i, edge.j)) {
            connections_successful += 1;
        }
    }

    std.debug.print("Attempted {d} connections, {d} successful\n", .{connections_attempted, connections_successful});

    // count circuit sizes
    var circuit_sizes = std.AutoHashMap(usize, usize).init(allocator);
    defer circuit_sizes.deinit();

    for (0..n) |i| {
        const root = uf.find(i);
        const entry = try circuit_sizes.getOrPut(root);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }

    // collect sizes and sort
    var sizes = std.ArrayList(usize).init(allocator);
    defer sizes.deinit();

    var it = circuit_sizes.valueIterator();
    while (it.next()) |size| {
        try sizes.append(size.*);
    }

    std.mem.sort(usize, sizes.items, {}, std.sort.desc(usize));

    std.debug.print("Number of circuits: {d}\n", .{sizes.items.len});
    
    // multiply the three largest (or fewer if not enough circuits)
    var result: usize = 1;
    const num_to_multiply = @min(3, sizes.items.len);
    std.debug.print("Top {d} circuit sizes: ", .{num_to_multiply});
    for (0..num_to_multiply) |i| {
        if (i > 0) std.debug.print(", ", .{});
        std.debug.print("{d}", .{sizes.items[i]});
        result *= sizes.items[i];
    }
    std.debug.print("\n", .{});
    std.debug.print("Result: {d}\n", .{result});
}
