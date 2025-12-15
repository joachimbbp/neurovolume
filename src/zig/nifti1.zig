const std = @import("std");
const print = std.debug.print;
const AccessError = error{NotSupportedYet};

pub const Header = extern struct {
    //_ signifies unused, just for ANALYZE formatting
    sizeofHdr: i32, //Must be 348
    _dataType: [10]u8,
    _dbName: [18]u8,
    _extents: i32,
    _sessionError: i16,
    _regular: u8,
    dimInfo: u8, //key for MRI slice ordering

    dim: [8]i16,
    intentP1: f32,
    intentP2: f32,
    intentP3: f32,
    intentCode: i16,
    datatype: i16,
    bitpix: i16,
    sliceStart: i16,
    pixdim: [8]f32,
    voxOffset: f32,
    sclSlope: f32,
    sclInter: f32,
    sliceEnd: i16,
    sliceCode: u8,
    xyztUnits: u8,
    calMax: f32,
    calMin: f32,
    sliceDuration: f32,
    toffset: f32,
    glmax: i32,
    glmin: i32,

    descrip: [80]u8,
    auxFile: [24]u8,

    qformCode: i16,
    sformCode: i16,
    quaternB: f32,
    quaternC: f32,
    quaternD: f32,
    qoffsetX: f32,
    qoffsetY: f32,
    qoffsetZ: f32,

    srowX: [4]f32,
    srowY: [4]f32,
    srowZ: [4]f32,

    intentName: [16]u8,

    magic: [4]u8,
};
//Maybe move to root? follow same pattern as measurementUnits_c
pub const DataType = enum(i16) {
    unknown = 0,
    bool = 1,
    unsigned_char = 2,
    signed_short = 4,
    signed_int = 8,
    float = 16,
    complex = 32,
    double = 64,
    rgb = 128,
    all = 255,
    signed_char = 256,
    unsigned_short = 512,
    unsigned_int = 768,
    long_long = 1024,
    unsigned_long_long = 1280,
    long_double = 1536,
    double_pair = 1792,
    long_double_pair = 2048,
    rgba = 2304,
    //anyhting else is unknown
    pub fn name(field: DataType) [:0]const u8 {
        return @tagName(field);
    }
};
pub fn minMax( //honestly: might be nifti specific! i think all files should have their own minmax maybe?
    comptime T: type, //must be float for now
    data: *const []const u8,
    bytes_per_voxel: u16, //NIfTI1 convention but should cover all cases
    slope: f32,
    intercept: f32,
) [3]T //min, max, max-min
{
    const num_voxels = data.len / @as(usize, @intCast(bytes_per_voxel)); //LLM:
    var minmax: [3]T = .{
        std.math.floatMax(T),
        -std.math.floatMax(T),
        undefined,
    };

    for (0..num_voxels) |idx| {
        const val = getValue(
            data,
            idx,
            bytes_per_voxel,
            i16,
            T,
            .little,
            2,
            slope,
            intercept,
            false,
            .{ 0, 0, 0 },
        );
        if (val < minmax[0]) {
            minmax[0] = val;
        }
        if (val > minmax[1]) {
            minmax[1] = val;
        }
    }
    minmax[2] = minmax[1] - minmax[0];
    return minmax;
}
fn getValue( //prbably nifti1 specific!
    data: *const []const u8,
    idx: usize, //linear index
    bytes_per_voxel: u16, //NIfTI1 convention, will cover all cases
    comptime VoxelType: type,
    endianness: std.builtin.Endian,

    //Scaling: set slope to 1 and int to 0 to have them not apply
    slope: f32,
    intercept: f32,

    //Normalizing
    normalize: bool,
    minmax: [3]f32, //min, max, max-min
) f32 {
    const bit_start: usize = idx * @as(usize, @intCast(bytes_per_voxel));
    const bit_end: usize = (idx + 1) * @as(usize, @intCast(bytes_per_voxel));
    const bytes_input = data.*[bit_start..bit_end]; //GPT: dereferencing suggested
    const type_size = @divExact(@typeInfo(VoxelType).int.bits, 8); //LLM: suggested
    const raw_value: f32 = @floatFromInt(std.mem.readInt(
        VoxelType,
        bytes_input[0..type_size],
        endianness,
    ));
    var res_value = raw_value;
    if (slope != 1 or intercept != 0) { //wouldn't change res_value
        res_value = slope * raw_value + intercept;
    }

    if (normalize) {
        res_value = (res_value - minmax[0]) / minmax[2];
    }
    return res_value;
}

pub fn getAt4D(
    self: *const Image,
    xpos: usize,
    ypos: usize,
    zpos: usize,
    tpos: usize,
    normalize: bool,
    minmax: [2]f32,
) !f32 {
    const nx: usize = @intCast(self.header.dim[1]);
    const ny: usize = @intCast(self.header.dim[2]);
    const nz: usize = @intCast(self.header.dim[3]);

    const idx: usize = tpos * nx * ny * nz + zpos * nx * ny + ypos * nx + xpos;

    const bit_start: usize = idx * @as(usize, @intCast(self.bytes_per_voxel));
    const bit_end: usize = (idx + 1) * @as(usize, @intCast(self.bytes_per_voxel));

    const raw_value = try byteToFloat(self.data, self.bytes_per_voxel, bit_start, bit_end);

    var post_slope = raw_value;
    if (self.header.sclSlope != 0) {
        post_slope = self.header.sclSlope * raw_value + self.header.sclInter;
    }

    if (normalize) {
        return (post_slope - minmax[0]) / (minmax[1] - minmax[0]); //TODO: calc the denom only once
    } else {
        return post_slope;
    }
}
pub fn byteToFloat(raw_data: []const u8, bytes_per_voxel: u16, bit_start: usize, bit_end: usize) !f32 {
    const ValType = switch (bytes_per_voxel) {
        2 => i16,
        //        2 => btf2(raw_data[bit_start..bit_end]),
        else => return AccessError.NotSupportedYet,
    };
    const val = std.mem.readInt(ValType, raw_data[bit_start..bit_end], .little); // i16, not u16
    return @floatFromInt(val);
}

//DEPRECATED: Image should be universal to all input formats, not just nifti 1
//header extraction has to become it's own thing too, so there's lots of
//stuff that will neeed DRYing in the future
pub const Image = struct {
    header: *const Header,
    data: []const u8,
    allocator: *const std.mem.Allocator,
    data_type: DataType,
    bytes_per_voxel: u16,

    pub fn printHeader(self: *const Image) void {
        print("🧠 Nifti Header:\n-------- \n{any}\n--------\n", .{self.header});
    }

    //DEPRECATED: This can be made much better
    pub fn init(filepath: []const u8) anyerror!Image {
        const allocator = &std.heap.page_allocator;
        //Load File
        const file = try std.fs.cwd().openFile(filepath, .{});
        defer file.close();

        //Load Header
        const reader = std.fs.File.deprecatedReader(file);

        const header_ptr = try allocator.create(Header);
        header_ptr.* = try reader.readStruct(Header);

        //Load Data
        const vox_offset = @as(u32, @intFromFloat(header_ptr.voxOffset));
        try file.seekTo(vox_offset);
        const file_size = try file.getEndPos();

        const raw_data = try allocator.alloc(u8, (file_size - vox_offset));
        _ = try file.readAll(raw_data);

        //datatype
        const data_type: DataType = @enumFromInt(header_ptr.*.datatype);
        const bytes_per_voxel: u16 = @intCast(@divTrunc(header_ptr.*.bitpix, 8));

        return Image{
            .header = header_ptr,
            .data = raw_data,
            .allocator = allocator,
            .data_type = data_type,
            .bytes_per_voxel = bytes_per_voxel,
        };
    }
    pub fn deinit(self: *const Image) void {
        //TODO: everything else
        //why did robbie put this as destroy for one and free for the other?
        self.allocator.destroy(self.header);
        self.allocator.free(self.data);
    }
};

pub fn getHeader(filepath: []const u8) !*const Header {
    const allocator = &std.heap.page_allocator;
    //Load File
    const file = try std.fs.cwd().openFile(filepath, .{});
    defer file.close();

    //Load Header
    const reader = std.fs.File.deprecatedReader(file);

    const header_ptr = try allocator.create(Header);
    header_ptr.* = try reader.readStruct(Header);

    //Load Data
    const vox_offset = @as(u32, @intFromFloat(header_ptr.voxOffset));
    try file.seekTo(vox_offset);
    const file_size = try file.getEndPos();

    const raw_data = try allocator.alloc(u8, (file_size - vox_offset));
    _ = try file.readAll(raw_data);

    return header_ptr;
}

pub fn getTransform(h: Header) ![4][4]f64 {
    return .{
        .{ h.srowX[0], h.srowX[1], h.srowX[2], h.srowX[3] },
        .{ h.srowY[0], h.srowY[1], h.srowY[2], h.srowY[3] },
        .{ h.srowZ[0], h.srowZ[1], h.srowZ[2], h.srowZ[3] },
        .{ 0.0, 0.0, 0.0, 1.0 },
    };
}

//SECTION: Tests:
const config = @import("config.zig.zon");

const t = @import("timer.zig");
test "echo module" {
    print("🧠 nifti1.zig module echo\n", .{});
}

test "non deprecated header techniques" {
    const static = config.testing.files.nifti1_t1;
    const hdr = try getHeader(static);
    const trans = try getTransform(hdr.*);
    //HACK: i feel like it would be better to pass the pointer
    print("🧙‍♂️🧠 Non deprecated header extraction {any}: \n", .{hdr.*});
    print("     extracted transform: {any}\n", .{trans});
}
