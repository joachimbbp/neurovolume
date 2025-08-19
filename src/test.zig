const std = @import("std");
const print = std.debug.print;
const testing = std.testing;

const nifti1 = @import("nifti1.zig");
const vdb543 = @import("vdb543.zig");

const output_path = "../output";

test "sphere" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    const allocator = arena.allocator();
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    const R: u32 = 128;
    const D: u32 = R * 2;
    const Identity4x4: [4][4]f64 = .{
        .{ 1.0, 0.0, 0.0, 0.0 },
        .{ 0.0, 1.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 1.0, 0.0 },
        .{ 0.0, 0.0, 0.0, 1.0 },
    };
    var sphere = try vdb543.build(allocator);
    const Rf: f32 = @floatFromInt(R);
    const R2: f32 = Rf * Rf;
    for (0..D - 1) |z| {
        for (0..D - 1) |y| {
            for (0..D - 1) |x| {
                const p = vdb543.toF32(.{ x, y, z });
                const diff = vdb543.subVec(p, .{ Rf, Rf, Rf });
                if (vdb543.lengthSquared(diff) < R2) {
                    try vdb543.setVoxel(&sphere, .{ @intCast(x), @intCast(y), @intCast(z) }, 1.0, allocator);
                }
            }
        }
    }
    vdb543.writeVDB(&buffer, &sphere, Identity4x4); // assumes compatible signature
    const sphere_file = try std.fs.cwd().createFile("/Users/joachimpfefferkorn/repos/neurovolume/output/0819a_zig.vdb", .{});
    defer sphere_file.close();
    try sphere_file.writeAll(buffer.items);
    print("Sphere test pattern written\n");
}

test "test_patern" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    const allocator = arena.allocator();
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var single_voxel = try vdb543.build(allocator);

    print("setting voxels\n", .{});
    try vdb543.setVoxel(&single_voxel, .{ @intCast(0), @intCast(0), @intCast(0) }, 1.0, allocator);
    const Identity4x4: [4][4]f64 = .{
        .{ 1.0, 0.0, 0.0, 0.0 },
        .{ 0.0, 1.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 1.0, 0.0 },
        .{ 0.0, 0.0, 0.0, 1.0 },
    };
    vdb543.writeVDB(&buffer, &single_voxel, Identity4x4); // assumes compatible signature
    //printBuffer(&buffer);

    const single_voxel_file = try std.fs.cwd().createFile("/Users/joachimpfefferkorn/repos/neurovolume/output/one_voxel_01_zig.vdb", .{});
    defer single_voxel_file.close();
    try single_voxel_file.writeAll(buffer.items);
}

test "nifti" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    const allocator = arena.allocator();

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    const path = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii";
    const img = try nifti1.Image.init(path);
    defer img.deinit();
    (&img).printHeader();
    const dims = img.header.dim;
    print("\nDimensions: {d}\n", .{dims});
    //check to make sure it's a static 3D image:
    if (dims[0] != 3) {
        print("Warning! Not a static 3D file. Has {d} dimensions\n", .{dims[0]});
    }
    const minmax = try nifti1.MinMax3D(img);
    var vdb = try VDB.build(allocator);

    print("iterating nifti file\n", .{});
    for (0..@as(usize, @intCast(dims[3]))) |z| {
        for (0..@as(usize, @intCast(dims[2]))) |x| {
            for (0..@as(usize, @intCast(dims[1]))) |y| {
                const val = try img.getAt4D(x, y, z, 0, true, minmax);
                //needs to be f16
                //TODO: probably you'll want normalization functions here, then plug it into the VDB (or an ACII visualizer, or image generator for debugging)
                //as in: norm_val = normalize(val, minmax)
                //TODO: vdb should accept multiple types
                try setVoxel(&vdb, .{ @intCast(x), @intCast(y), @intCast(z) }, @floatCast(val), allocator);
            }
        }
    }
    const Identity4x4: [4][4]f64 = .{
        .{ 1.0, 0.0, 0.0, 0.0 },
        .{ 0.0, 1.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 1.0, 0.0 },
        .{ 0.0, 0.0, 0.0, 1.0 },
    };
    writeVDB(&buffer, &vdb, Identity4x4); // assumes compatible signature
    //printBuffer(&buffer);

    const file0 = try std.fs.cwd().createFile("/Users/joachimpfefferkorn/repos/neurovolume/output/nifti_zig.vdb", .{});
    defer file0.close();
    try file0.writeAll(buffer.items);
    print("\nnifti file written\n", .{});
}
