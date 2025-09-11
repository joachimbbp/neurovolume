//_: IMPORTS
const std = @import("std");
const print = std.debug.print;
const zools = @import("zools/src/root.zig");
const debug = @import("debug.zig");
const nifti1 = @import("nifti1.zig");
const ArrayList = std.array_list.Managed;
const vdb543 = @import("vdb543.zig");
//WARNING: Do I need call conventions?
//_: Debug Functions

// Print functions to test importing
pub export fn hello() void {
    print("🪾 Root level print\n", .{});
    debug.helloNeurovolume();
    zools.debug.helloZools();
}

pub export fn echo(word: [*:0]const u8) [*:0]const u8 {
    print("zig level echo print: {s}\n", .{word});
    return word;
}

// const ReturnErrAndString = extern struct {
//     err: u8,
//     string: [*:0]const u8,
// }; //BUG: giving up on this for now
//

pub export fn echoHam(word: [*:0]const u8, output_buffer: [*]u8, buf_len: usize) usize {
    //LLM: body is chatGPT
    const input = std.mem.span(word);
    const suffix = " ham";
    const total_len = input.len + suffix.len;

    if (total_len + 1 > buf_len) {
        // Not enough room (leave buffer empty or truncated)
        return 0;
    }

    // Copy input
    @memcpy(output_buffer[0..input.len], input); //HUMAN EDIT:
    // Append suffix
    @memcpy(output_buffer[input.len..][0..suffix.len], suffix); //HUMAN EDIT:
    // Null terminate
    output_buffer[total_len] = 0;

    return total_len;
    //LLM END:
}
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const alloc = gpa.allocator();
//     defer _ = gpa.deinit();
//
//     const result = std.fmt.allocPrint(alloc, "{s} ham", .{word}) catch {
//         unreachable;
//     };
//     defer alloc.free(result);
//     return std.mem.span(result);
// }

// //TODO: python readable error handling
// pub export fn nifti1ToVDB(nifti_path: [*:0]const u8, output_path: [*:0]const u8, normalize: bool) [*:0]u8 {
//     const filepath = std.mem.span(nifti_path);
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const gpa_alloc = gpa.allocator(); //TODO: standardize these
//     defer _ = gpa.deinit();
//     var arena = std.heap.ArenaAllocator.init(gpa_alloc);
//     defer arena.deinit();
//     const allocator = arena.allocator();
//
//     var buffer = ArrayList(u8).init(allocator);
//     defer buffer.deinit();
//
//     const img = nifti1.Image.init(filepath) catch unreachable;
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
//     const save_path = zools.save.version(output_path, buffer, allocator) catch unreachable;
//     return save_path.items;
// }
