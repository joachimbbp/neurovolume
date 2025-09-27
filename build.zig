const std = @import("std");

pub fn build(b: *std.Build) void {
    //TODO: reintroduce testing options here,
    //possibly package that in the demo?

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zools = b.dependency("zools", .{
        .target = target,
        .optimize = optimize,
    }).module("zools");

    const libneurovolume = b.addLibrary(.{
        .name = "neurovolume",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("./src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    libneurovolume.root_module.addImport("zools", zools);
    //NOTE: This is really just for testing purposes
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
}
