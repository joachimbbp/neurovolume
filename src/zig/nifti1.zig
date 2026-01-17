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

fn getFPS(hdr: Header) !f32 {
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

//TODO: let's actually break out the file loading
//int a separate function!
//It's computationally expensive so it would be good
//to only call that once and then just have
//a universal volume loading from the frames???

pub fn loadFrames(
    filepath: []const u8,
    alloc: std.mem.Allocator,
) .{ [][]f32, Header } {}

//TODO: move this to volume
pub fn toVolume(
    //take in the hader too built by loadFrames
    playback_fps: f32,
    speed: f32,
    effects: []const *const fn (vol: *vol.Volume) [][]f32,
    interpolation: *const fn (vol: *vol.Volume) [][]f32,
) !vol.Volume {

    //Load File
    const file = try std.fs.cwd().openFile(filepath, .{});
    defer file.close();

    //Load Header
    const reader = std.fs.File.deprecatedReader(file);

    const hdr = try alloc.create(Header);
    hdr.* = try reader.readStruct(Header);
    defer alloc.destroy(hdr);

    //Load Data
    const vox_offset = @as(u32, @intFromFloat(hdr.voxOffset));
    try file.seekTo(vox_offset);
    const file_size = try file.getEndPos();

    const raw_data = try alloc.alloc(u8, (file_size - vox_offset));
    _ = try file.readAll(raw_data);
    defer alloc.destroy(raw_data);

    const name = util.stripped_basename(filepath);
    const transform = try getTransform(hdr.*);
    const fps = try getFPS(hdr);
    const dims: [3]usize = .{ @intCast(hdr.dim[1]), @intCast(hdr.dim[2]), @intCast(hdr.dim[3]) };
    const cartesian_order: [3]usize = .{ 0, 1, 2 };

    //TODO: continued, yeah so htis right here would be the volume loading!
    //
    //datatype
    const data_type: DataType = @enumFromInt(hdr.*.datatype);
    const bytes_per_voxel: u16 = @intCast(@divTrunc(hdr.*.bitpix, 8));

    for (0..hdr.dim[4]) |frame_num| {}

    return vol.Volume{
        .name = name,

        //.frames
        .transform = transform,

        .source_fps = fps,
        .playback_fps = playback_fps,
        .speed = speed,

        .dims = &dims,
        .c_o = &cartesian_order,
    };
}
