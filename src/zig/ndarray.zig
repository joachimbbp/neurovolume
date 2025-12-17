const vdb543 = @import("vdb543.zig");
const std = @import("std");
const util = @import("util.zig");
const vol = @import("volume.zig");
const constants = @import("constants.zig");
pub export fn toFrame(
    data: [*]const f32,
    dims: *const [3]usize,
) usize {
    const cartesian_order = [3]usize{ 2, 1, 0 };
    vol.Frame{
        .data = data,
        .dims = *dims,
        .c_o = &cartesian_order,
    };
}
//
//
// var vdb = vdb543.VDB.build(arena_alloc) catch {
//     return 0;
// };
// var cart = [_]u32{ 0, 0, 0 };
// var idx: usize = 0;
//
//NOTE: nested for-loop might be more performant on ndarrays (at least in this implementation)

//     //Cart matches ndarray order
//     vdb543.setVoxel(
//         &vdb,
//         .{ cart[2], cart[1], cart[0] },
//         data[idx],
//         arena_alloc,
//     ) catch {
//         print("set voxel error!\n", .{});
//         return 0;
//     };
// }
//
// var buffer = std.array_list.Managed(u8).init(arena_alloc);
// defer buffer.deinit();
// const transform_matrix = [4][4]f64{
//     .{ transform[0], transform[1], transform[2], transform[3] },
//     .{ transform[4], transform[5], transform[6], transform[7] },
//     .{ transform[8], transform[9], transform[10], transform[11] },
//     .{ transform[12], transform[13], transform[14], transform[15] },
// };
// vdb543.writeVDB(&buffer, &vdb, transform_matrix) catch {
//     std.debug.print("ERROR: Failed to write VDB\n", .{});
//     return 0;
// };
//
// const file = std.fs.cwd().createFile(std.mem.span(output_filepath), .{}) catch {
//     std.debug.print("ERROR: Failed to create file\n", .{});
//     return 0;
// };
// file.writeAll(buffer.items) catch {
//     std.debug.print("ERROR: Failed to write to file\n", .{});
//     return 0;
// };
// defer file.close();
// std.debug.print("vdb successfully built from array\n", .{});
// return 1;
