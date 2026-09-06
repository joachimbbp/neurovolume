const std = @import("std");
const print = std.debug.print;

//builds C library for Python hooks
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });
    const nvol_mod = b.createModule(.{
        .root_source_file = b.path("./src/zig/c_root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tag = target.result.os.tag;
    const lib_ext = switch (tag) {
        .macos => "dylib",
        .linux => "so", // per claude
        .windows => "dll", // per claude
        else => @panic(b.fmt("Unsupported target OS for build, target.os.tag={s}", .{@tagName(tag)})),
    };

    print("target.os.tag={s}, lib_ext={s}", .{ @tagName(tag), lib_ext });

    const libneurovolume = b.addLibrary(.{
        .name = "neurovolume",
        .linkage = .dynamic,
        .root_module = nvol_mod,
    });

    //NOTE: This doesn't really do much at the moment
    const exe = b.addExecutable(.{
        .name = "demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("./src/zig/demo_temp.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.root_module.linkLibrary(libneurovolume);
    b.installArtifact(libneurovolume);
    b.installArtifact(exe);
    //_: Zig TESTS:

    const mod_tests = b.addTest(.{
        .root_module = nvol_mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);
    //get your print statements:
    run_mod_tests.has_side_effects = true;
    // run_mod_tests.stdio = .inherit; //doesn't capture stderr for some reason (LLM suggested)

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);

    //_: copy binaries:
    //LLM: heavy LLM inspo here
    const install_lib = b.addInstallArtifact(libneurovolume, .{});
    const dest_path = b.fmt("../src/neurovolume/_native/libneurovolume.{s}", .{lib_ext});
    const copy_lib = b.addInstallFile(libneurovolume.getEmittedBin(), dest_path);
    copy_lib.step.dependOn(&install_lib.step);
    b.getInstallStep().dependOn(&copy_lib.step);
}
