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

    //WARN:
    //Let's see if it's possible to put a function here?

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
    fn name(field: DataType) [:0]const u8 {
        return @tagName(field);
    }
    pub fn get(hdr_ptr: *Header) !DataType {
        const data_type_tag: DataType = @enumFromInt(hdr_ptr.*.datatype);
        return DataType.name(data_type_tag);
    }
};

pub fn loadHeaderPointer(filepath: []const u8, alloc: std.mem.Allocator) !*Header {
    const file = try std.fs.cwd().openFile(filepath, .{});
    defer file.close();
    const reader = std.fs.File.deprecatedReader(file);
    const header_ptr = try alloc.create(Header);
    header_ptr.* = try reader.readStruct(Header);
    return header_ptr;
}

pub fn getRawData(filepath: []const u8) ![]u8 {
    const alloc = &std.heap.page_allocator; //WARN: why page_allocator?

    const file = try std.fs.cwd().openFile(filepath, .{});
    defer file.close();
    const hdr_ptr = loadHeaderPointer(filepath, alloc);
    const vox_offset = @as(u32, @intFromFloat(hdr_ptr.voxOffset));
    try file.seekTo(vox_offset);
    const file_size = try file.getEndPos();

    const raw_data = try alloc.alloc(u8, (file_size - vox_offset)); //wow, CURSED: naming!
    try file.readAll(raw_data);
    return raw_data;
}

pub fn getAt4D(
    xpos: usize,
    ypos: usize,
    zpos: usize,
    tpos: usize,
    data: []u8,
    header_pointer: Header,
    normalize: bool,
    minmax: [2]f32,
) !f32 {
    const nx: usize = @intCast(header_pointer.*.dim[1]);
    const ny: usize = @intCast(header_pointer.*.dim[2]);
    const nz: usize = @intCast(header_pointer.*.dim[3]);

    const idx: usize = tpos * nx * ny * nz + zpos * nx * ny + ypos * nx + xpos;

    const bytes_per_voxel: u16 = @intCast(@divTrunc(header_pointer.*.bitpix, 8));
    const bit_start: usize = idx * @as(usize, @intCast(bytes_per_voxel));
    const bit_end: usize = (idx + 1) * @as(usize, @intCast(bytes_per_voxel));

    const raw_value = try byteToFloat(
        data,
        bytes_per_voxel,
        bit_start,
        bit_end,
    );

    //OPTIMIZE: not the most performant at the moment, but I'm going to replace
    //the whole shebang with Jan's get_at logic, so I'm not going to focus
    //on optimizing this temporary code
    var post_slope = raw_value;
    if (header_pointer.*.sclSlope != 0) {
        post_slope = header_pointer.*.sclSlope * raw_value + header_pointer.*.sclInter;
    }

    if (normalize) {
        return (post_slope - minmax[0]) / (minmax[1] - minmax[0]);
    } else {
        return post_slope;
    }
}

pub fn printHeader(hdr_ptr: *Header) void {
    //TODO: this could use some custom parsing etc
    print("🧠 Nifti Header:\n-------- \n{any}\n--------\n", .{hdr_ptr});
}

fn byteToFloat(raw_data: []const u8, bytes_per_voxel: u16, bit_start: usize, bit_end: usize) !f32 {
    const raw_value = switch (bytes_per_voxel) {
        2 => btf2(raw_data[bit_start..bit_end]),
        //TODO: all of the other byte to float functions!
        //which migth requrie multiple types?
        else => return AccessError.NotSupportedYet,
    };
    return raw_value;
}

fn btf2(bytes: []const u8) f32 {
    const value = std.mem.readInt(i16, bytes[0..2], .little); // i16, not u16
    return @floatFromInt(value);
}

pub fn getBytesPerVoxel(hdr_ptr: *Header) !u16 {
    const bytes_per_voxel: u16 = @intCast(@divTrunc(hdr_ptr.*.bitpix, 8));
    return bytes_per_voxel;
}

pub fn getHeader(filepath: []const u8) !*Header {
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

pub fn getMinMax3D(dim: [4]usize) ![2]f32 {
    //OPTIMIZE: this could probably mimic Jan's eventual logic in getAt4D
    var minmax: [2]f32 = .{ std.math.floatMax(f32), -std.math.floatMax(f32) };
    for (0..@as(usize, @intCast(dim[3]))) |z| {
        for (0..@as(usize, @intCast(dim[2]))) |y| {
            for (0..@as(usize, @intCast(dim[1]))) |x| {
                const val = try getAt4D(x, y, z, 0, false, .{ 0, 0 });
                if (val < minmax[0]) {
                    minmax[0] = val;
                }
                if (val > minmax[1]) {
                    minmax[1] = val;
                }
            }
        }
    }
    return minmax;
}

//SECTION: Tests:
const config = @import("config.zig.zon");
test "echo module" {
    print("🧠 nifti1.zig module echo\n", .{});
}

test "open and normalize nifti file" {
    print("🧠 Opening and normalizing nifti1 file\n", .{});
    const static = config.testing.files.nifti1_t1;
    const hdr_ptr = try getHeader(static);
    printHeader(hdr_ptr);
    print("\ndatatype: {s}\n", .{DataType.get(hdr_ptr)});
    const bpv = try getBytesPerVoxel(hdr_ptr);
    print("bytes per voxel: {any}\n", .{bpv});

    const mid_x: usize = @divFloor(@as(usize, @intCast(hdr_ptr.*.img.header.dim[1])), 2);
    const mid_y: usize = @divFloor(@as(usize, @intCast(hdr_ptr.*.img.header.dim[2])), 2);
    const mid_z: usize = @divFloor(@as(usize, @intCast(hdr_ptr.*.dim[3])), 2);
    const mid_t: usize = @divFloor(@as(usize, @intCast(hdr_ptr.*.dim[4])), 2);
    const minmax = try getMinMax3D(mid_x, mid_y, mid_z, mid_t);
    const raw_data = try getRawData(static);

    const mid_value = try getAt4D(
        mid_x,
        mid_y,
        mid_z,
        mid_t,
        raw_data,
        hdr_ptr,
        true,
        minmax,
    );

    print("middle value: {any}\n", .{mid_value});

    print("Normalizing\nSetting Min Max\n", .{});
    print("Min Max: {any}\n", .{minmax});
    const normalized_mid_value = try getAt4D(
        mid_x,
        mid_y,
        mid_z,
        mid_t,
        true,
        minmax,
    );
    print("Normalized mid value: {any}\n", .{normalized_mid_value});
}

test "non deprecated header techniques" {
    const static = config.testing.files.nifti1_t1;
    const hdr = try getHeader(static);
    const trans = try getTransform(hdr.*);
    //HACK: i feel like it would be better to pass the pointer
    print("🧙‍♂️🧠 Non deprecated header extraction {any}: \n", .{hdr.*});
    print("     extracted transform: {any}\n", .{trans});
}
