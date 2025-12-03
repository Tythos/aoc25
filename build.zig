const std = @import("std");

pub fn build(b: *std.Build) void {
    // define standard options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // define program executable (installable)
    const exe = b.addExecutable(.{
        .name = "aoc25",
        .root_source_file = b.path("src/day2/part2.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    // define run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
