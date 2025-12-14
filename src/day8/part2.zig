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
    num_circuits: usize,
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
            .num_circuits = n,
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
        
        self.num_circuits -= 1;
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

    // connect pairs until all junction boxes are in one circuit
    var uf = try UnionFind.init(allocator, n);
    defer uf.deinit();

    var last_connection_i: usize = 0;
    var last_connection_j: usize = 0;
    
    for (edges.items) |edge| {
        if (uf.unite(edge.i, edge.j)) {
            last_connection_i = edge.i;
            last_connection_j = edge.j;
            
            if (uf.num_circuits == 1) {
                // All boxes are now in one circuit
                break;
            }
        }
    }

    std.debug.print("Number of circuits remaining: {d}\n", .{uf.num_circuits});
    std.debug.print("Last connection was between boxes {d} and {d}\n", .{last_connection_i, last_connection_j});
    std.debug.print("Box {d}: {d},{d},{d}\n", .{last_connection_i, coords.items[last_connection_i].x, coords.items[last_connection_i].y, coords.items[last_connection_i].z});
    std.debug.print("Box {d}: {d},{d},{d}\n", .{last_connection_j, coords.items[last_connection_j].x, coords.items[last_connection_j].y, coords.items[last_connection_j].z});
    
    const result = coords.items[last_connection_i].x * coords.items[last_connection_j].x;
    std.debug.print("Result: {d}\n", .{result});
}
