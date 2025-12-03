const std = @import("std");

pub fn main() !void {
    // define allocator, tracking variables
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var pos: i32 = 50;
    var n0: u32 = 0;

    // parse input from stdout into lines
    const stdin = std.io.getStdIn();
    const content = try stdin.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(content);
    var lines = std.ArrayList([]const u8).init(allocator);
    defer lines.deinit();
    var iterator = std.mem.splitSequence(u8, content, "\n");
    while (iterator.next()) |line| {
        if (line.len == 0) continue;
        try lines.append(line);
    }

    // step through lines (rotations) and update position
    for (lines.items) |line| {
        const dir: u8 = line[0];
        const steps: u32 = std.fmt.parseInt(u32, line[1..], 10) catch |err| {
            std.debug.print("Invalid steps: {}\n", .{err});
            return error.InvalidSteps;
        };
        if (dir == 'L') {
            pos = @mod(pos - @as(i32, @intCast(steps)), 100);
        } else if (dir == 'R') {
            pos = @mod(pos + @as(i32, @intCast(steps)), 100);
        } else {
            std.debug.print("Invalid direction: {c}\n", .{dir});
            return error.InvalidDirection;
        }
        if (pos == 0) {
            n0 += 1;
        }
    }

    std.debug.print("n0: {}\n", .{n0});
}
