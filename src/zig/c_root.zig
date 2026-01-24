const ndarray = @import("ndarray.zig");
const Volume = @import("volume.zig").Volume;
const std = @import("std");
const ArrayList = std.array_list.Managed;

// Converts a 3D ndarray into a frame and appends it to a volume
// For sequences, iterate through the 4th dimension
// Returns error code
pub export fn ndarrayToFrame(
    data_ptr: [*]f32,
    data_len: usize,
    frame_num: usize,
    volume: *Volume,
) c_int {
    const data = data_ptr[0..data_len];
    ndarray.toFrame(&data, frame_num, volume) catch |e| {
        return cErr(e).code;
    };
    return 0;
}

pub export fn volumeInit(
    //BOOKMARK: return to this later after you get nifti1 working natively!
    name_ptr: [*:0]const u8,
    data: [*]const f32, //all frames flattened
    transform_flat: *const [16]f64,
    source_fps: f32,
    playback_fps: f32,
    speed: f32,
    dims: *const [3]usize,
    cartesian_order: *const [3]usize,
    out_volume: **Volume,
) c_int {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();
    // Reshape flat transform into [4][4]f64 LLM:
    var transform: [4][4]f64 = undefined;
    for (0..4) |i| {
        for (0..4) |j| {
            transform[i][j] = transform_flat[i * 4 + j];
        }
    }

    const frame_size = dims[0] * dims[1] * dims[2];
    const num_frames = data / frame_size;

    var frames = std.array_list.Managed([]f32).init(gpa_alloc);
    for (0..num_frames) |f| {
        const pos = f * frame_size;
        const end = pos + frame_size;
        frames.append(data[pos..end]);
    }

    // Initialize the Volume
    const volume = Volume{
        .name = name_ptr,
        .frames = frames,
        .transform = transform,
        .source_fps = source_fps,
        .playback_fps = playback_fps,
        .speed = speed,
        .dims = dims.*,
        .cartesian_order = cartesian_order.*,
        .effects = &[_]*const fn (*Volume) [][]f32{},
        .interpolation = undefined, // Must be set later
    };

    out_volume.* = volume;
    return 0;
}

//TODO: volume deinit (either here or in volume.zig)

//TODO: Volume apply effects and interpolation

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
