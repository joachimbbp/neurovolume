//TODO:
//These tests are very incomplete as this project is WIP
//It would be nice to have some cool emojis (especially 🧠, 🧲, ⚪️)

const std = @import("std");
const print = std.debug.print;
const testing = std.testing;
//HACK: there is a more legit way to do this in the build system, I'm sure
const zools = @import("zools/src/root.zig"); //MY SUBMODULE:
const t = zools.timer;
const nifti1 = @import("nifti1.zig");
const vdb543 = @import("vdb543.zig");
const VDB = vdb543.VDB;
const output_path = "../output";

const ArrayList = std.array_list.Managed;

test "imports" {
    zools.debug.helloZools();
    for (0..5) |_| {
        print("random uuid: {s}\n", .{zools.uuid.v4()});
    }
}
test "timers" {
    //NOTE: This is more or less the pattern
    const timer_start = t.Click();
    defer t.Stop(timer_start);
    defer print("\ntimer test:\n", .{});
    std.Thread.sleep(3333000);
}
test "sphere" {
    const timer_start = t.Click();
    defer t.Stop(timer_start);
    defer print("\n⏰ sphere timer:\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    const allocator = arena.allocator();
    //WARNING: this naming convention is really
    //weird and certainly differs from zools!
    var buffer = ArrayList(u8).init(allocator);
    defer buffer.deinit();

    const R: u32 = 128;
    const D: u32 = R * 2;
    const Identity4x4: [4][4]f64 = .{
        .{ 1.0, 0.0, 0.0, 0.0 },
        .{ 0.0, 1.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 1.0, 0.0 },
        .{ 0.0, 0.0, 0.0, 1.0 },
    };

    var sphere = try VDB.build(allocator); //.build(allocator);
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

    const file_name = try zools.save.version("./output/0819a_zig.vdb", buffer, allocator);
    print("Sphere test pattern written to  {s}\n", .{file_name.items});
}

test "test_patern" {
    const timer_start = t.Click();
    defer t.Stop(timer_start);
    defer print("\n⏰test pattern timer:\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    const allocator = arena.allocator();
    var buffer = ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var single_voxel = try VDB.build(allocator);

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

    const file_path = "./output/one_voxel_01_zig.vdb";
    const versioned_name = try zools.save.version(file_path, buffer, allocator);
    print("saved to {s}\n", .{versioned_name.items});
}

test "nifti" {
    const timer_start = t.Click();
    defer t.Stop(timer_start);
    defer print("\n⏰nifti timer:\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    const allocator = arena.allocator();

    var buffer = ArrayList(u8).init(allocator);
    defer buffer.deinit();

    const path = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii";
    const img = try nifti1.Image.init(path);
    defer img.deinit();
    (&img).printHeader();
    const dims = img.header.dim;
    print("\nDimensions: {any}\n", .{dims});
    //check to make sure it's a static 3D image:
    if (dims[0] != 3) {
        print("Warning! Not a static 3D file. Has {any} dimensions\n", .{dims[0]});
    }
    const minmax = try nifti1.MinMax3D(img);
    var vdb = try VDB.build(allocator);

    print("iterating nifti file\n", .{});
    for (0..@as(usize, @intCast(dims[3]))) |z| {
        for (0..@as(usize, @intCast(dims[2]))) |x| {
            for (0..@as(usize, @intCast(dims[1]))) |y| {
                const val = try img.getAt4D(x, y, z, 0, true, minmax);
                //needs to be f16
                try vdb543.setVoxel(&vdb, .{ @intCast(x), @intCast(y), @intCast(z) }, @floatCast(val), allocator);
            }
        }
    }
    const Identity4x4: [4][4]f64 = .{
        .{ 1.0, 0.0, 0.0, 0.0 },
        .{ 0.0, 1.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 1.0, 0.0 },
        .{ 0.0, 0.0, 0.0, 1.0 },
    };
    vdb543.writeVDB(&buffer, &vdb, Identity4x4); // assumes compatible signature
    const save_path = "./output/nifti_zig.vdb";
    const file_name = try zools.save.version(save_path, buffer, allocator);
    print("\nnifti file written to {}\n", .{file_name});
}

test "open and normalize nifti file" {
    const timer_start = t.Click();
    defer t.Stop(timer_start);
    defer print("\n⏰ open and normalize nifti file timer:\n", .{});

    const static = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii";
    var img = try nifti1.Image.init(static);
    defer img.deinit();
    (&img).printHeader();
    print("\ndatatype: {s}\n", .{nifti1.DataType.name(img.data_type)});
    print("bytes per voxel: {any}\n", .{img.bytes_per_voxel});

    const mid_x: usize = @divFloor(@as(usize, @intCast(img.header.dim[1])), 2);
    const mid_y: usize = @divFloor(@as(usize, @intCast(img.header.dim[2])), 2);
    const mid_z: usize = @divFloor(@as(usize, @intCast(img.header.dim[3])), 2);
    const mid_t: usize = @divFloor(@as(usize, @intCast(img.header.dim[4])), 2);

    const mid_value = try img.getAt4D(mid_x, mid_y, mid_z, mid_t, false, .{ 0, 0 });

    print("middle value: {any}\n", .{mid_value});

    print("Normalizing\nSetting Min Max\n", .{});
    const minmax = try nifti1.MinMax3D(img);
    print("Min Max: {any}\n", .{minmax});
    const normalized_mid_value = try img.getAt4D(mid_x, mid_y, mid_z, mid_t, true, minmax);
    print("Normalized mid value: {any}\n", .{normalized_mid_value});
}
