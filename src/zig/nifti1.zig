const std = @import("std");
const vol = @import("volume.zig");
const util = @import("util.zig");
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

    dim: [8]i16, //number of dimensions, x, y, z, t, optional, optional, optional
    //if dim[0] is not between 1-7, assume opposite endianness and byte swap
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
    //Source data
    hdr: Header,
    data: []const u8,
    //positions:
    xpos: usize,
    ypos: usize,
    zpos: usize,
    tpos: usize,
    //normalization:
    normalize: bool,
    //    minmax: [2]f32,
    min_val: f32, //minmax[0]
    minmax_delta: f32, //minax[1] - minmax[0]
) !f32 {
    const bytes_per_voxel: u16 = @intCast(@divTrunc(hdr.bitpix, 8));

    const nx: usize = @intCast(hdr.dim[1]);
    const ny: usize = @intCast(hdr.dim[2]);
    const nz: usize = @intCast(hdr.dim[3]);
    const idx: usize = tpos * nx * ny * nz + zpos * nx * ny + ypos * nx + xpos;

    const bit_start: usize = idx * @as(usize, @intCast(bytes_per_voxel));
    const bit_end: usize = (idx + 1) * @as(usize, @intCast(bytes_per_voxel));

    const raw_value = try byteToFloat(data, bytes_per_voxel, bit_start, bit_end);

    var post_slope = raw_value;
    if (hdr.sclSlope != 0) {
        post_slope = hdr.sclSlope * raw_value + hdr.sclInter;
    }

    if (normalize) {
        return (post_slope - min_val) / minmax_delta;
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

const Nifti1Unpacked = struct { hdr: *Header, data: *[]u8 };

pub fn load(
    allocator: std.mem.Allocator,
    filepath: []const u8,
) !Nifti1Unpacked {
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

    //LLM: suggested revision of this line:
    const raw_data = try allocator.alloc(u8, (file_size - vox_offset));
    _ = try file.readAll(raw_data);

    return .{ .hdr = header_ptr, .data = &raw_data };
}

fn getTransform(h: Header) ![4][4]f64 {
    return .{
        .{ h.srowX[0], h.srowX[1], h.srowX[2], h.srowX[3] },
        .{ h.srowY[0], h.srowY[1], h.srowY[2], h.srowY[3] },
        .{ h.srowZ[0], h.srowZ[1], h.srowZ[2], h.srowZ[3] },
        .{ 0.0, 0.0, 0.0, 1.0 },
    };
}
//gets the xyzt_units from nifti
const Unit = enum(u8) {
    Unknown = 0,
    //spatial
    Meter = 1,
    Milimeter = 2,
    Micron = 3,
    //temporal
    Seconds = 8,
    Miliseconds = 16,
    Microseconds = 24,
    Hertz = 32,
    Parts_per_million = 40,
    Radians_per_second = 48,
};
//returns space, time
fn getUnits(
    hdr: *Header,
) [2]Unit {
    const field = hdr.xyztUnits;
    //LLM: bitwise code more or less copypasta
    const spatial_code = field & 0x07;
    const temporal_code = (field & 0x38) >> 3;

    const space: Unit = @enumFromInt(spatial_code);
    const time: Unit = @enumFromInt(temporal_code << 3);
    return .{ space, time };
}

fn getFPS(hdr: *Header) !f32 {
    const num_frames = hdr.dim[4];
    if (num_frames == 1) {
        //static file, thus fps of 0
        return 0.0;
    }
    const units = getUnits(hdr);
    const time = units[1];
    const time_value = hdr.pixdim[4];
    const fps = switch (time) {
        Unit.Seconds => 1.0 / time_value,
        Unit.Miliseconds => 0.001 / time_value,
        Unit.Microseconds => 0.000001 / time_value,
        else => {
            print("ERROR: {s} not supported yet\n", .{time});
            return AccessError.NotSupportedYet;
        },
    };
    return fps;
}

fn makeFrameList(n1u: Nifti1Unpacked) ![*][]f32 {
    const data_type: DataType = @enumFromInt(n1u.hdr_ptr.datatype);
    const bytes_per_voxel: u16 = @intCast(@divTrunc(n1u.hdr_ptr.bitpix, 8));
    const num_voxels = n1u.hdr.dim[1] * n1u.hdr.dim[2] * n1u.hdr.dim[2];

    var frame_list: [*][]f32 = undefined;
    for (0..num_voxels) |v| {
        //BOOKMARK: increment cartesian or something here?
        if 
    }
}

pub fn toVolume(
    allocator: std.mem.Allocator,
    //take in the hader too built by loadFrames
    filepath: []const u8,
    playback_fps: f32,
    speed: f32,
) !vol.Volume {
    const n1u = try load(allocator, filepath);
    const name = util.stripped_basename(filepath);
    const transform = try getTransform(n1u.hdr);

    const fps = try getFPS(n1u.hdr);
    const dims: [3]usize = .{
        @intCast(n1u.hdr.dim[1]),
        @intCast(n1u.hdr.dim[2]),
        @intCast(n1u.hdr.dim[3]),
    };
    const cartesian_order: [3]usize = .{ 0, 1, 2 };

    //TODO: create frame list
    //?: is that the best intermediary? Ithink so!
    //will need to re-implement getAt as not a method
    //and call it here!

    const volume = try vol.Volume.init(
        allocator,
        name,
    );
}
