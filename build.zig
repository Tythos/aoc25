const std = @import("std");

pub fn build(b: *std.Build) void {
    // define standard options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // define program executable (installable)
    const exe = b.addExecutable(.{
        .name = "aoc25",
        .root_source_file = b.path("src/day7/part2.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    // link against utils module
    const utils_module = b.addModule("utils", .{
        .root_source_file = b.path("src/utils.zig"),
    });
    exe.root_module.addImport("utils", utils_module);

    // define run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // add test step
    const utils_tests = b.addTest(.{
        .root_source_file = b.path("src/utils.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_utils_tests = b.addRunArtifact(utils_tests);
    
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_utils_tests.step);
    b.default_step = test_step;
}
