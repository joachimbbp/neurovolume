const ndarray = @import("ndarray.zig");
const Volume = @import("volume.zig").Volume;
const std = @import("std");

pub export fn toFrame(
    data: []f32,
    frame_num: usize,
    volume: *Volume,
) usize {
    //LLM:
    if (frame_num >= volume.frame_count) return cErr(error.IndexOutOfBounds);
    const frame_size = volume.dims[0] * volume.dims[1] * volume.dims[2];
    volume.frames[frame_num] = data[0..frame_size];
    return 0; // success
}

//_: ERROR UTILS:
pub fn cErr(e: anyerror) CError {
    const name = @errorName(e);
    return .{
        .code = @intFromError(e),
        .name = name.ptr,
        .len = name.len,
    };
}

pub const CError = extern struct {
    code: usize,
    name: [*]const u8,
    len: usize,
};

//LLM: suggested python side:
//  Python side:
// class NeuroVolumeError(Exception):
//     """Base exception for neurovolume"""
//     pass
// def check_error(result):
//     if result.code != 0:
//         error_name = ctypes.string_at(result.name, result.len).decode('utf-8')
//         raise NeuroVolumeError(f"{error_name} (code: {result.code})")
//DEPRECATED:
// //_: IMPORTS
// const std = @import("std");
// const print = std.debug.print;
// const util = @import("util.zig");
// const zip = util.zipPairs;
// const nifti1 = @import("nifti1.zig");
// const vdb543 = @import("vdb543.zig");
// const root = @import("root.zig");
// const t = @import("timer.zig");
// const constants = @import("constants.zig");
//
// //_: CONSTS:
// const config = @import("config.zig.zon");
// const SupportError = error{
//     Dimensions,
// };
// //_: Globals:
// //LLM: suggested to make allocators global
// var gpa = std.heap.GeneralPurposeAllocator(.{}){};
// const gpa_alloc = gpa.allocator();
// var arena = std.heap.ArenaAllocator.init(gpa_alloc);
// const arena_alloc = arena.allocator();
//
// //_: C library:
//
// // Print "hello neurovolume" to terminal for testing purposes
// pub export fn hello() void {
//     print("hello neurovolume\n", .{});
// }
// test "hello" {
//     hello();
// }
//
// //DEPRECATED: this should really be split out
// pub export fn nifti1ToVDB_c(
//     fpath: [*:0]const u8,
//     output_dir: [*:0]const u8,
//     normalize: bool,
//     fpath_buff: [*]u8,
//     fpath_cap: usize,
// ) usize {
//     const fpath_slice: []const u8 = std.mem.span(fpath); //LLM: suggested line
//     const output_dir_slice: []const u8 = std.mem.span(output_dir);
//     const filepath = root.nifti1ToVDB(
//         fpath_slice,
//         output_dir_slice,
//         normalize,
//         arena_alloc,
//     ) catch {
//         return 0;
//     };
//     const n = if (filepath.len + 1 <= fpath_cap) filepath.len else fpath_cap - 1;
//     @memcpy(fpath_buff[0..n], filepath[0..n]);
//     arena_alloc.free(filepath);
//     return n;
// }
//
// //_: voxels
// //DEPRECATED: likewise, this could live in VDB?
// pub export fn setVoxel_c(
//     vdb: *vdb543.VDB,
//     pos: *const [3]u32,
//     value: f32,
// ) usize {
//     vdb543.setVoxel(vdb, .{ pos.*[0], pos.*[1], pos.*[2] }, value, arena_alloc) catch {
//         return 0;
//     };
//     return 1;
//     //WARN: don't forget to free everything in this arena after writing the VDB!
// }
//
// test "static nifti to vdb - c level" {
//     //note: there's a little mismatch in the testing/actual functionality at the moment, hence this:
//     //perhaps: reconcile these by bringing the tmp save out of the function itself and then calling
//     //either that or the default persistent location in the real nifti1tovdb function!
//
//     print("🌊 c level nifti to vdb\n", .{});
//
//     var fpath_buff: [4096]u8 = undefined; //very arbitrary length!
//     //todo: make the lenght a bit more robust. what should it be???
//
//     const start = t.Click();
//     const fpath_len = nifti1ToVDB_c(
//         config.testing.files.nifti1_t1,
//         config.paths.vdb_output_dir,
//         true,
//         &fpath_buff,
//         fpath_buff.len,
//     );
//     _ = t.Lap(start, "static nifti1 to vdb timer");
//     print("☁️ 🧠 static nifti test saved as vdb\n", .{});
//     print("🗃️ output filepath:\n       {s}\n", .{fpath_buff[0..fpath_len]});
// }
// test "bold nifti to vdb - c level" {
//     print("🌊 c level bold nifti to vdb\n", .{});
//
//     var fpath_buff: [4096]u8 = undefined; //very arbitrary length!
//     //todo: make the lenght a bit more robust. what should it be???
//
//     const start = t.Click();
//     const fpath_len = nifti1ToVDB_c(
//         config.testing.files.bold,
//         config.paths.vdb_output_dir,
//         true,
//         &fpath_buff,
//         fpath_buff.len,
//     );
//     _ = t.Lap(start, "bold nifti timer");
//     print("☁️🩸🧠 bold nifti test saved as vdb\n", .{});
//     const bhdr = try nifti1.getHeader(config.testing.files.bold);
//     const b_trans = try nifti1.getTransform(bhdr.*);
//     print("         transform: {any}\n", .{b_trans});
//     print("🗃️ output filepath:\n       {s}\n", .{fpath_buff[0..fpath_len]});
// }
