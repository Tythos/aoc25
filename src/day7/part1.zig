const std = @import("std");
const utils = @import("utils");

const IterationResult = struct {
    line_index: u16,
    num_splits: u16,
    new_line: []const u8,

    fn print(self: *const IterationResult) void {
        std.debug.print("line index: {}\n", .{self.line_index});
        std.debug.print("number of splits: {}\n", .{self.num_splits});
        std.debug.print("new line: {s}\n", .{self.new_line});
    }
};

fn iterate_manifold(allocator: std.mem.Allocator, lines: std.ArrayList([]const u8)) !IterationResult {
    // find the first line with no tachyon beams ("|") or start of beams ("S")
    var i: usize = 0;
    for (lines.items) |line| {
        if (utils.contains(line, "S")) {
            // start of the manifold
            i += 1;
            continue;
        } else if (!utils.contains(line, "|")) {
            break;
        } else {
            i += 1;
        }
    }

    // the new state of this line observes the following rules:
    // - any "." immediately below an start ("S") becomes a beam ("|")
    // - any "." immediately adjacent to a splitter ("^") becomes a beam IFF that splitter has a beam above it
    // - any "." immediately below a beam beccomes a beam
    // - any non-"." character does not change
    //
    // lastly, we count how many times a beam is split
    var num_splits: u16 = 0;
    var current_line = try allocator.dupe(u8, lines.items[i]);
    const previous_line = lines.items[i - 1];
    for (current_line, 0..) |c, j| {
        if (c == '.') {
            if (previous_line[j] == 'S') {
                current_line[j] = '|';
            } else if (previous_line[j] == '|') {
                current_line[j] = '|';
            } else if (j > 0 and current_line[j-1] == '^') {
                // splitter to the left
                if (previous_line[j-1] == '|') {
                    current_line[j] = '|';
                }
            } else if (j < current_line.len - 1 and current_line[j+1] == '^') {
                // splitter to the right
                if (previous_line[j+1] == '|') {
                    current_line[j] = '|';
                }
            }
        } else if (c == '^') {
            // beam propagation takes place in the "." case so we can just count split activations
            if (previous_line[j] == '|') {
                num_splits += 1;
            }
        }
    }

    // return index of line, updated line contents, and how many splits took place
    return IterationResult{
        .line_index = @as(u16, @intCast(i)),
        .num_splits = num_splits,
        .new_line = current_line,
    };
}

fn swap_line_and_free(allocator: std.mem.Allocator, lines: std.ArrayList([]const u8), iteration_result: IterationResult) void {
    const old_line = lines.items[iteration_result.line_index];
    defer allocator.free(old_line);
    lines.items[iteration_result.line_index] = iteration_result.new_line;
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

    // count splits over all iterations
    var total_splits: u16 = 0;
    var iteration_result: IterationResult = undefined;
    std.debug.print("{s}\n", .{lines.items[0]});

    // iterate manifold lines
    for (1..lines.items.len) |_| {
        iteration_result = try iterate_manifold(allocator, lines);
        total_splits += iteration_result.num_splits;
        swap_line_and_free(allocator, lines, iteration_result);
        std.debug.print("{s}\n", .{iteration_result.new_line});
    }

    // finally, report total number of splits
    std.debug.print("total number of splits: {}\n", .{total_splits});
}
