const std = @import("std");
const print = std.debug.print;
const zools = @import("zools");
const t = zools.timer;
const vdb543 = @import("vdb543.zig");
const VDB = vdb543.VDB;

pub const TestPatternError = error{
    PersistentSaveNotImplementedYet,
};

//Use "tmp" to override save path to a temporary output

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
// }
