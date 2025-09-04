const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod_name = "neurovolume";
    const mod = b.addModule(mod_name, .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    _ = mod;
    //
    // const lib_unit_tests = b.addTest(.{
    //     .name = "tests",
    //     .root_module = b.addModule("zools", .{
    //         .root_source_file = b.path("src/all_tests.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //     }),
    // });
    // const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    //    lib_unit_tests.root_module.addImport("zools", mod);
    //    const test_step = b.step("test", "Run unit tests");
    //    test_step.dependOn(&run_lib_unit_tests.step);
}
