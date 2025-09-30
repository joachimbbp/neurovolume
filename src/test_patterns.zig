const std = @import("std");
const print = std.debug.print;
const zools = @import("zools");
const t = zools.timer;
const vdb543 = @import("vdb543.zig");
const VDB = vdb543.VDB;

const TestPatternError = error{
    PersistentSaveNotImplementedYet,
};

const Identity4x4: [4][4]f64 = .{
    .{ 1.0, 0.0, 0.0, 0.0 },
    .{ 0.0, 1.0, 0.0, 0.0 },
    .{ 0.0, 0.0, 1.0, 0.0 },
    .{ 0.0, 0.0, 0.0, 1.0 },
};

//Use "tmp" to override save path to a temporary output
pub fn sphere(comptime save_dir: []const u8) !void {
    print("⚪️ Sphere Test Pattern\n", .{});
    //NICE: This seems to follow the idiomatic pattern for arena: https://zig.guide/master/standard-library/allocators
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    const alloc = arena.allocator();

    var buffer = std.array_list.Managed(u8).init(alloc);
    defer buffer.deinit();
    const R: u32 = 128;
    const D: u32 = R * 2;
    var sphere_vdb = try VDB.build(alloc);
    const Rf: f32 = @floatFromInt(R);
    const R2: f32 = Rf * Rf;
    for (0..D - 1) |z| {
        for (0..D - 1) |y| {
            for (0..D - 1) |x| {
                const p = vdb543.toF32(.{ x, y, z });
                const diff = vdb543.subVec(p, .{ Rf, Rf, Rf });
                if (vdb543.lengthSquared(diff) < R2) {
                    try vdb543.setVoxel(&sphere_vdb, .{ @intCast(x), @intCast(y), @intCast(z) }, 1.0, alloc);
                }
            }
        }
    }
    try vdb543.writeVDB(&buffer, &sphere_vdb, Identity4x4); // assumes compatible signature
    const basename = "sphere_test_pattern";
    const fmt = "{s}/{s}.vdb";
    var save_path = try std.fmt.allocPrint(alloc, fmt, .{ save_dir, basename });
    defer alloc.free(save_path);
    if (std.mem.eql(u8, save_dir, "tmp") == true) {
        var tmp_dir = std.testing.tmpDir(.{});
        defer tmp_dir.cleanup();
        const tmp_dir_slice = try tmp_dir.dir.realpathAlloc(alloc, ".");
        save_path = try std.fmt.allocPrint(alloc, fmt, .{ tmp_dir_slice, basename });
        const final_save_location = try zools.save.version(save_path, buffer, alloc);
        print("Sphere test pattern saved to: {s}\n", .{final_save_location.items});
    } else {
        print("Error: custom save directory not implemented yet. 'tmp' is not given string:\n{s}", .{save_dir});
        return TestPatternError.PersistentSaveNotImplementedYet;
        //TODO: Implement
    }
}

// test "test_patern" {
//     const timer_start = t.Click();
//     defer t.Stop(timer_start);
//     defer print("\n⏰test pattern timer:\n", .{});
//
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const gpa_alloc = gpa.allocator();
//     defer _ = gpa.deinit();
//     var arena = std.heap.ArenaAllocator.init(gpa_alloc);
//     defer arena.deinit();
//     const allocator = arena.allocator();
//     var buffer = ArrayList(u8).init(allocator);
//     defer buffer.deinit();
//
//     var single_voxel = try VDB.build(allocator);
//
//     print("setting voxels\n", .{});
//     try vdb543.setVoxel(&single_voxel, .{ @intCast(0), @intCast(0), @intCast(0) }, 1.0, allocator);
//     const Identity4x4: [4][4]f64 = .{
//         .{ 1.0, 0.0, 0.0, 0.0 },
//         .{ 0.0, 1.0, 0.0, 0.0 },
//         .{ 0.0, 0.0, 1.0, 0.0 },
//         .{ 0.0, 0.0, 0.0, 1.0 },
//     };
//     try vdb543.writeVDB(&buffer, &single_voxel, Identity4x4); // assumes compatible signature
//     //printBuffer(&buffer);
//
//     const file_path = "./output/one_voxel_01_zig.vdb";
//     const versioned_name = try zools.save.version(file_path, buffer, allocator);
//     print("saved to {s}\n", .{versioned_name.items});
// }
//
// test "nifti" {
//     const timer_start = t.Click();
//     defer t.Stop(timer_start);
//     defer print("\n⏰nifti timer:\n", .{});
//
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const gpa_alloc = gpa.allocator();
//     defer _ = gpa.deinit();
//     var arena = std.heap.ArenaAllocator.init(gpa_alloc);
//     defer arena.deinit();
//     const allocator = arena.allocator();
//
//     var buffer = ArrayList(u8).init(allocator);
//     defer buffer.deinit();
//
//     const path = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii";
//     const img = try nifti1.Image.init(path);
//     defer img.deinit();
//     (&img).printHeader();
//     const dims = img.header.dim;
//     print("\nDimensions: {any}\n", .{dims});
//     //check to make sure it's a static 3D image:
//     if (dims[0] != 3) {
//         print("Warning! Not a static 3D file. Has {any} dimensions\n", .{dims[0]});
//     }
//     const minmax = try nifti1.MinMax3D(img);
//     var vdb = try VDB.build(allocator);
//
//     print("iterating nifti file\n", .{});
//     for (0..@as(usize, @intCast(dims[3]))) |z| {
//         for (0..@as(usize, @intCast(dims[2]))) |x| {
//             for (0..@as(usize, @intCast(dims[1]))) |y| {
//                 const val = try img.getAt4D(x, y, z, 0, true, minmax);
//                 //needs to be f16
//                 try vdb543.setVoxel(&vdb, .{ @intCast(x), @intCast(y), @intCast(z) }, @floatCast(val), allocator);
//             }
//         }
//     }
//     const Identity4x4: [4][4]f64 = .{
//         .{ 1.0, 0.0, 0.0, 0.0 },
//         .{ 0.0, 1.0, 0.0, 0.0 },
//         .{ 0.0, 0.0, 1.0, 0.0 },
//         .{ 0.0, 0.0, 0.0, 1.0 },
//     };
//     try vdb543.writeVDB(&buffer, &vdb, Identity4x4); // assumes compatible signature
//     const save_path = "./output/nifti_zig.vdb";
//     const file_name = try zools.save.version(save_path, buffer, allocator);
//     print("\nnifti file written to {}\n", .{file_name});
// }
