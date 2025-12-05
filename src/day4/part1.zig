const std = @import("std");
const utils = @import("utils");

// fn ndx_to_ij(ndx: u16, I: u16, J: u16) (u16, u16) {
//     const i = @divFloor(ndx, J);
//     const j = ndx % J;
//     return (i, j);
// }

fn ij_to_ndx(i: u16, j: u16, I: u16, J: u16) u16 {
    _ = I;
    return i * J + j;
}

fn debug_print_map(map: []const u8, I: u16, J: u16) void {
    for (0..I) |i| {
        for (0..J) |j| {
            const i_u16 = @as(u16, @intCast(i));
            const j_u16 = @as(u16, @intCast(j));
            std.debug.print("{c}", .{map[ij_to_ndx(i_u16, j_u16, I, J)]});
        }
        std.debug.print("\n", .{});
    }
}

fn count_free_neighbors(map: []const u8, i: u16, j: u16, I: u16, J: u16) u16 {
    var n_free: u16 = 0;
    for (0..3) |di| {
        for (0..3) |dj| {
            if (di == 1 and dj == 1) {
                n_free += 0;
            } else if (i + di < 1 or i + di >= I + 1) {
                n_free += 1;
            } else if (j + dj < 1 or j + dj >= J + 1) {
                n_free += 1;
            } else {
                const i_u16 = @as(u16, @intCast(i + di - 1));
                const j_u16 = @as(u16, @intCast(j + dj - 1));
                if (map[ij_to_ndx(i_u16, j_u16, I, J)] == '.') {
                    n_free += 1;
                }
            }
        }
    }
    return n_free;
}

pub fn main() !void {
    // define program allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // read input from stdin
    const stdin = try utils.read_from_stdin(allocator);
    defer allocator.free(stdin);

    // first we need to measure the dimensions (I rows, J columns)
    const lines = try utils.split_string_by_delimiter(allocator, stdin, "\n");
    defer lines.deinit();
    const I: u16 = @as(u16, @intCast(lines.items.len));
    const J: u16 = @as(u16, @intCast(lines.items[0].len));
    std.debug.print("There are {} rows and {} columns\n", .{I, J});

    // define map as array of arrays (u8)
    const map = try allocator.alloc(u8, I * J);
    defer allocator.free(map);
    for (lines.items, 0..) |line, i| {
        for (line, 0..) |c, j| {
            const i_u16 = @as(u16, @intCast(i));
            const j_u16 = @as(u16, @intCast(j));
            map[ij_to_ndx(i_u16, j_u16, I, J)] = @as(u8, @intCast(c));
        }
    }
    debug_print_map(map, I, J);
    std.debug.print("\n", .{});

    // for each cell with a `@`, check number of `@`s in 8-neighborhood
    var n_free_total: u16 = 0;
    for (0..I) |i| {
        const i_u16 = @as(u16, @intCast(i));
        for (0..J) |j| {
            const j_u16 = @as(u16, @intCast(j));
            if (map[ij_to_ndx(i_u16, j_u16, I, J)] == '@') {
                const n_free: u16 = count_free_neighbors(map, i_u16, j_u16, I, J);
                if (8 - n_free < 4) { // "fewer than four rolls... adjacent"
                    map[ij_to_ndx(i_u16, j_u16, I, J)] = 'x';
                    n_free_total += 1;
                }
            }
        }
    }
    debug_print_map(map, I, J);
    std.debug.print("Number of free cells: {}\n", .{n_free_total});
}
