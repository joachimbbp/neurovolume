//_: IMPORTS
const std = @import("std");
const print = std.debug.print;
const zools = @import("zools/src/root.zig");
const debug = @import("debug.zig");
const nifti1 = @import("nifti1.zig");
const ArrayList = std.array_list.Managed;
const vdb543 = @import("vdb543.zig");
//_: Debug Functions

// Print functions to test importing
pub export fn hello() void {
    print("🪾 Root level print\n", .{});
    debug.helloNeurovolume();
    zools.debug.helloZools();
}
pub export fn echo(c_string: [*:0]const u8) void {
    const slice = std.mem.span(c_string);
    print("{s}\n", .{slice});
}

//TODO: configurable files with output path, overrides in functions, etc.
//HACK:
//But for now:
//
// const save_path = "./output/nifti_zig.vdb";
//
// pub export fn nifti1ToVDB(nifti_path: []const u8, normalize: bool) void {
//     //BUG: It appears I can't give error unions when building libraries
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
//     const img = nifti1.Image.init(nifti_path.*) catch unreachable;
//     defer img.deinit();
//     (&img).printHeader();
//     const dims = img.header.dim;
//     print("\nDimensions: {any}\n", .{dims});
//     //check to make sure it's a static 3D image:
//     if (dims[0] != 3) {
//         print("Warning! Not a static 3D file. Has {any} dimensions\n", .{dims[0]});
//     }
//     const minmax = nifti1.MinMax3D(img) catch unreachable;
//     var vdb = vdb543.VDB.build(allocator) catch unreachable;
//
//     print("iterating nifti file\n", .{});
//     for (0..@as(usize, @intCast(dims[3]))) |z| {
//         for (0..@as(usize, @intCast(dims[2]))) |x| {
//             for (0..@as(usize, @intCast(dims[1]))) |y| {
//                 const val = img.getAt4D(x, y, z, 0, normalize, minmax) catch unreachable;
//                 vdb543.setVoxel(&vdb, .{ @intCast(x), @intCast(y), @intCast(z) }, @floatCast(val), allocator) catch unreachable;
//             }
//         }
//     }
//     const Identity4x4: [4][4]f64 = .{
//         .{ 1.0, 0.0, 0.0, 0.0 },
//         .{ 0.0, 1.0, 0.0, 0.0 },
//         .{ 0.0, 0.0, 1.0, 0.0 },
//         .{ 0.0, 0.0, 0.0, 1.0 },
//     };
//     vdb543.writeVDB(&buffer, &vdb, Identity4x4); // assumes compatible signature
//     _ = zools.save.version(save_path, buffer, allocator) catch unreachable;
// }
