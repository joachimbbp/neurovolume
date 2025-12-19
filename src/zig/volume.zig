const std = @import("std");
const nifti1 = @import("nifti1.zig");
const util = @import("util.zig");
const cErr = util.cErr;
const vdb543 = @import("vdb543.zig");

//TODO: move to vdb543.zig
// pub fn dataToVDB(
//     self: *Volume,
//     alloc: std.mem.Allocator,
//     save_path: [*:0]const u8,
// ) usize {
//     var vdb = vdb543.VDB.build(alloc) catch |e| {
//         return cErr(e);
//     };
//
//     var cart = [_]u32{ 0, 0, 0 };
//     var idx: usize = 0;
//     const minmax = util.minMax(
//         f32,
//         self.data,
//         self.sclSlope,
//         self.sclInter,
//     );
//     while (util.incrementCartesian(3, &cart, .dims)) {
//         idx += 1;
//         const res_value = nifti1.getValue(
//             .data,
//             idx,
//             .bytes_per_voxel,
//             i16,
//             .little,
//             self.sclSlope,
//             self.sclInter,
//             normalize,
//             minmax,
//         );
//         try vdb543.setVoxel(
//             &vdb,
//             .{ cart[self.c_o[0]], cart[self.c_o[1]], cart[self.c_o[2]] },
//             res_value,
//             alloc,
//         );
//
//         var buffer = std.array_list.Managed(u8).init(alloc);
//         defer buffer.deinit();
//
//         //WARN: you must overwrite, version, or skip at the function call!
//         const file = std.fs.cwd().createFile(save_path, .{}) catch |e| {
//             cErr(e);
//         };
//         try file.writeAll(buffer.items);
//         defer file.close();
//     }
// }
//

pub const Volume = extern struct {
    //Loaded from source
    name: [*:0]const u8,
    frames: [*]const []f32,

    fps_source: usize,
    fps_playback: usize,
    speed: f32, //0.0 for still, 1.0 for normal, 2.0 for 2X speed

    dims: *const [3]usize,
    c_o: *const [3]usize, // Cartesian coordinaes Order

    effects: []const *const fn (v: *Volume) [][]f32, //effects are applied on the data in memory
    interpolation: *const fn (v: *Volume) [][]f32, //interpolation happens while creating the VDB

    pub fn render_effects(self: *Volume) void {
        for (self.effects) |effect| {
            self.frames = effect(self) catch |e| {
                cErr(e);
            };
        }
    }
    pub fn toVDB(
        self: *Volume,
        alloc: std.mem.Allocator,
        save_path: [*:0]const u8,
    ) usize {
        var vdb = vdb543.VDB.build(alloc) catch |e| {
            return cErr(e);
        };
        for (self.frames) |frame| {
            var cart = [_]u32{ 0, 0, 0 };
            var i: usize = 0;
            while (util.incrementCartesian(3, &cart, .dims)) {
                i += 1;
                try vdb543.setVoxel(
                    &vdb,
                    .{ cart[self.c_o[0]], cart[self.c_o[1]], cart[self.c_o[2]] },
                    frame[i],
                    alloc,
                );
            }

            var buffer = std.array_list.Managed(u8).init(alloc);
            defer buffer.deinit();

            //WARN: you must overwrite, version, or skip at the function call!
            const file = std.fs.cwd().createFile(save_path, .{}) catch |e| {
                cErr(e);
            };
            try file.writeAll(buffer.items);
            defer file.close();
        }
    }
};

//TODO: instead of Composition, just have a set of
//effects that allows you to combine volumes in different
//ways (time stretch for T1 on a BOLD overlay, method of subtraction,
//classic scalar addition, etc).

//WARN:
//Hey maybe these should all just be
// in their own modules? That way this
// is the only thing that need to deal with
// c ABI weirdness
// pub export fn from_ndarray(
//     data: [*]const f32,
//     dims: *const [3]usize,
//     transform: *const [16]f64,
//     output_filepath: [*:0]const u8,
// ) usize {}

// Returns ptr to Volume
// pub fn from_NIfTI1(filepath: [*:0]const u8) usize {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     defer _ = gpa.deinit();
//     var arena = std.heap.ArenaAllocator.init(gpa.allocator()); //LLM: suggested
//     defer arena.deinit();
//
//     const file = std.fs.cwd().openFile(filepath, .{}) catch |e| {
//         return cErr(e);
//     };
//     defer file.close();
//
//     const reader = std.fs.File.deprecatedReader(file); // DEPRECATED:
//     const header_ptr = arena.child_allocator.create(nifti1.Header) catch |e| {
//         return cErr(e);
//     };
//     header_ptr.* = reader.readStruct(nifti1.Header) catch |e| {
//         return cErr(e);
//     };
//     const vox_offset = @as(u32, @intFromFloat(header_ptr.voxOffset));
//     try file.seekTo(vox_offset);
//     const file_size = try file.getEndPos();
//
//     const raw_data = arena.child_allocator.alloc(u8, (file_size - vox_offset)) catch |e| {
//         return cErr(e);
//     };
//     _ = try file.readAll(raw_data);
//
//     const data_type: nifti1.DataType = @enumFromInt(header_ptr.*.datatype);
//     const bytes_per_voxel: u16 = @intCast(@divTrunc(header_ptr.*.bitpix, 8));
//
//     const minmax = nifti1.minMax(
//         f32,
//         &raw_data,
//         bytes_per_voxel,
//         header_ptr.*.sclSlope, //sclSlope,
//         header_ptr.*.sclInter,
//     );
//     // BOOKMARK: continue at root -> switch (img.header.dim[0]
// }
