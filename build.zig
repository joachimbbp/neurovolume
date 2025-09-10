const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libneurovolume = b.addLibrary(.{
        .name = "neurovolume",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("./src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const exe = b.addExecutable(.{
        .name = "demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/demo_temp.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.linkLibrary(libneurovolume);
    b.installArtifact(libneurovolume);
    b.installArtifact(exe);
    // const mod = b.addModule("neurovolume", .{
    //     .root_source_file = b.path("src/root.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    //HACK: currently zools is just in src
    // const zools_dep = b.dependency("zools", .{
    //     .target = target,
    //     .optimize = optimize,
    // });
    // const zools_mod = zools_dep.module("zools");
    //    // mod.addImport("zools", zools_mod);

    // const lib_unit_tests = b.addTest(.{
    //     .name = "tests",
    //     .root_module = b.addModule("neurovolume", .{
    //         .root_source_file = b.path("src/test.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //     }),
    // });
    // const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    // lib_unit_tests.root_module.addImport("neurovolume", mod);
    // // lib_unit_tests.root_module.addImport("zools", zools_mod);
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_lib_unit_tests.step);
}
