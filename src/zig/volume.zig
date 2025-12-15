const std = @import("std");
const nifti1 = @import("nifti1.zig");
const util = @import("util.zig");
const cErr = util.cErr;
const vdb543 = @import("vdb543.zig");

pub const Volume = extern struct {
    // Single scan volume
    // (or combination of scans into one volume)
    name: [*:0]const u8,
    frames: [*]const Frame,
    fps: u8,
};

pub const Frame = extern struct {
    data: [*]const f32,
    dims: *const [3]usize,
    transform: *const [3][3]f64,
    bytes_per_voxel: *u16,
    sclSlope: f32,
    sclInter: f32,
    c_o: *const [3]usize, // Cartesian coordinaes Order
    // ndarray is 2 1 0
    // nifti1 is 0 1 2

    pub fn toVDB(
        self: *Frame,
        alloc: std.mem.Allocator,
        normalize: bool,
        save_path: [*:0]const u8,
    ) usize {
        var vdb = vdb543.VDB.build(alloc) catch |e| {
            return cErr(e);
        };

        var cart = [_]u32{ 0, 0, 0 };
        var idx: usize = 0;
        const minmax = util.minMax(
            f32,
            self.data,
            self.sclSlope,
            self.sclInter,
        );
        while (util.incrementCartesian(3, &cart, .dims)) {
            idx += 1;
            const res_value = nifti1.getValue(
                .data,
                idx,
                .bytes_per_voxel,
                i16,
                .little,
                self.sclSlope,
                self.sclInter,
                normalize,
                minmax,
            );
            try vdb543.setVoxel(
                &vdb,
                .{ cart[self.c_o[0]], cart[self.c_o[1]], cart[self.c_o[2]] },
                res_value,
                alloc,
            );

            var buffer = std.array_list.Managed(u8).init(alloc);
            defer buffer.deinit();
            const versioned_vdb_filepath = try vdb543.writeFrame(
                &buffer,
                &vdb,
                save_path,
                alloc,
                self.transform,
            );
            // FIX: versioning is a little fucked here
            // it really should check versioning and decide
            // to overwrite, version, or skip at that level
        }
    }
};
pub export fn ndArrayToVDB(
    data: [*]const f32,
    dims: *const [3]usize,
    transform: *const [16]f64,
    output_filepath: [*:0]const u8,
) usize {}

// Returns ptr to Volume
pub fn from_NIfTI1(filepath: [*:0]const u8) usize {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator()); //LLM: suggested
    defer arena.deinit();

    const file = std.fs.cwd().openFile(filepath, .{}) catch |e| {
        return cErr(e);
    };
    defer file.close();

    const reader = std.fs.File.deprecatedReader(file); // DEPRECATED:
    const header_ptr = arena.child_allocator.create(nifti1.Header) catch |e| {
        return cErr(e);
    };
    header_ptr.* = reader.readStruct(nifti1.Header) catch |e| {
        return cErr(e);
    };
    const vox_offset = @as(u32, @intFromFloat(header_ptr.voxOffset));
    try file.seekTo(vox_offset);
    const file_size = try file.getEndPos();

    const raw_data = arena.child_allocator.alloc(u8, (file_size - vox_offset)) catch |e| {
        return cErr(e);
    };
    _ = try file.readAll(raw_data);

    const data_type: nifti1.DataType = @enumFromInt(header_ptr.*.datatype);
    const bytes_per_voxel: u16 = @intCast(@divTrunc(header_ptr.*.bitpix, 8));

    const minmax = nifti1.minMax(
        f32,
        &raw_data,
        bytes_per_voxel,
        header_ptr.*.sclSlope, //sclSlope,
        header_ptr.*.sclInter,
    );
    // BOOKMARK: continue at root -> switch (img.header.dim[0]
}
pub const Composition = extern struct {
    volumes: [*]const volume,
    fps: u8,
};
