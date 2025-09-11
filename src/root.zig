//_: IMPORTS
const std = @import("std");
const print = std.debug.print;
const zools = @import("zools/src/root.zig");
const debug = @import("debug.zig");
const nifti1 = @import("nifti1.zig");
const ArrayList = std.array_list.Managed;
const vdb543 = @import("vdb543.zig");
//_: Debug and Test Functions
pub export fn hello() void {
    print("🪾 Root level print\n", .{});
    debug.helloNeurovolume();
    zools.debug.helloZools();
}
pub export fn echo(word: [*:0]const u8) [*:0]const u8 {
    print("zig level echo print: {s}\n", .{word});
    return word;
}
pub export fn echoHam(word: [*:0]const u8, output_buffer: [*]u8, buf_len: usize) usize {
    //LLM START:
    const input = std.mem.span(word);
    const suffix = " ham";
    const total_len = input.len + suffix.len;
    if (total_len + 1 > buf_len) {
        return 0;
    }
    @memcpy(output_buffer[0..input.len], input); //HUMAN EDIT: changed to @memcpy
    @memcpy(output_buffer[input.len..][0..suffix.len], suffix); //HUMAN EDIT:
    output_buffer[total_len] = 0; // Null terminate

    return total_len;
    //LLM END:
}

pub export fn alwaysFails() usize {
    std.testing.expect(true == false) catch
        {
            return 0;
        };
    return 1;
}

//LLM:
pub export fn writePathToBufC(
    path_nt: [*:0]const u8, // C string from Python
    out_buf: [*]u8,
    out_cap: usize,
) usize {
    if (out_cap == 0) return 0;

    const src = std.mem.span(path_nt); // []const u8 (no NUL)
    const want = src.len;
    const n = if (want + 1 <= out_cap) want else out_cap - 1;

    @memcpy(out_buf[0..n], src[0..n]);
    out_buf[n] = 0; // NUL-terminate

    return n; // bytes written (excludes NUL)
}
//LLM END:

//Writes to the buffer, file saving happens on the python level
// pub export fn nifti1ToVDB(nifti_path: [*:0]const u8, normalize: bool, path_buf: [*]u8, path_buf_len: usize) usize {
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
//     const img = nifti1.Image.init(filepath) catch {
//         return 0;
//     };
//     defer img.deinit();
//     //    (&img).printHeader();
//
//     const dims = img.header.dim;
//     //    print("\nDimensions: {any}\n", .{dims});
//     if (dims[0] != 3) {
//         print("Warning! Not a static 3D file. Has {any} dimensions\n", .{dims[0]});
//     } //TODO: just generally check if it's a valid Nifti1 file!
//
//     const minmax = nifti1.MinMax3D(img) catch {
//         return 0;
//     };
//     var vdb = vdb543.VDB.build(allocator) catch {
//         return 0;
//     };
//
//     print("iterating nifti file\n", .{});
//     for (0..@as(usize, @intCast(dims[3]))) |z| {
//         for (0..@as(usize, @intCast(dims[2]))) |x| {
//             for (0..@as(usize, @intCast(dims[1]))) |y| {
//                 const val = img.getAt4D(x, y, z, 0, normalize, minmax) catch {
//                     return 0;
//                 };
//                 vdb543.setVoxel(&vdb, .{ @intCast(x), @intCast(y), @intCast(z) }, @floatCast(val), allocator) catch {
//                     return 0;
//                 };
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
//     const save_path = "./output/nifti_zig.vdb";
//     const file_path = zools.save.version(save_path, buffer, allocator) catch {
//         return 0;
//     };
//     print("\nnifti file written to {}\n", .{file_path});
//
//     //NOTE: To return the name:
//     @memcpy(path_buf[0..path_buf_len], std.mem.span(file_path.items[0..file_path.items.len]));
//     //BUG: file_path.items is incorrect
//     const total_len = path_buf_len + buffer.capacity; //Q: so does the buf_len not really matter?
//     path_buf[total_len] = 0; //null terminate
//     return total_len;
// }
