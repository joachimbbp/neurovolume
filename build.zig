const std = @import("std");

pub fn build(b: *std.Build) void {
    //TODO:
    // - [ ] test the c_root level
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zools = b.dependency("zools", .{
        .target = target,
        .optimize = optimize,
    }).module("zools");

    const nvol_mod = b.createModule(.{
        .root_source_file = b.path("./src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    nvol_mod.addImport("zools", zools);

    const libneurovolume = b.addLibrary(.{
        .name = "neurovolume",
        .linkage = .dynamic,
        .root_module = nvol_mod,
    });

    //libneurovolume.root_module.addImport("zools", zools);

    //NOTE: This doesn't really do much at the moment
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
    //_: Zig TESTS:

    const mod_tests = b.addTest(.{
        .root_module = nvol_mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
