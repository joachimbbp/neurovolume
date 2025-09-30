const std = @import("std");
const print = std.debug.print;
const AccessError = error{NotSupportedYet};

//WIP: packed header (commented out for now)
// pub const PackedHeader = packed struct {
//     //SOURCE: https://brainder.org/2012/09/23/the-nifti-file-format/
//     sizeof_hdr: enum(i32) {
//         default = 348,
//     } = .default,
//     _1: [10]u8, //data_type
//     _2: [18]u8, //db_name
//     _3: [14]u8, //extents
//     _4: [2]u8, //session_error
//     _5: [1]u8, //regular
//     dim_info: enum(u8) {
//         one = 1,
//         two = 2,
//         three = 3,
//     },
//     dim: packed struct { // TODO: add std.Io.Limit
//         number_of_dimensions: i16,
//         x: i16,
//         y: i16,
//         z: i16,
//         t: i16,
//         optional_dim_1: i16,
//         optional_dim_2: i16,
//         optional_dim_3: i16,
//     },
//     intent: packed struct {
//         //NOTE: Might be a way to have a union here to use
//         //different structs based on the intent code?
//         p1: f32,
//         p2: f32,
//         p3: f32,
//         code: enum(i16) {
//             //WARN: Not checked with NIH specs
//             none = 0,
//             corelation = 2,
//             t_test = 3,
//             f_test = 4,
//             z_score = 5,
//             chi_squared_statistic = 6,
//             beta_distribution = 7,
//             //TODO:... contnue
//         },
//     },
// };
//
// const Intent = union {
//     none: [3]f32,
// }; //all params + actual intent code
//
pub const Header = extern struct {
    sizeofHdr: i32, //Must be 348
    dataType: [10]u8,
    dbName: [18]u8,
    extents: i32,
    sessionError: i16,
    regular: u8,
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

//DEPRECATED: Image should be universal to all input formats, not just nifti 1
pub const Image = struct {
    header: *const Header,
    data: []const u8,
    allocator: *const std.mem.Allocator,
    data_type: DataType,
    bytes_per_voxel: u16,

    pub fn getAt4D(self: *const Image, xpos: usize, ypos: usize, zpos: usize, tpos: usize, normalize: bool, minmax: [2]f32) !f32 {
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

    pub fn printHeader(self: *const Image) void {
        print("{any}", .{self.header});
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
    //TODO: You need to prep the image with minmax to get the normalization function!
    //Some oop-y design habits to destory!
    //
    //
    pub fn deinit(self: *const Image) void {
        //TODO: everything else
        //why did robbie put this as destroy for one and free for the other?
        self.allocator.destroy(self.header);
        self.allocator.free(self.data);
    }
};
pub fn MinMax3D(img: Image) ![2]f32 {
    var minmax: [2]f32 = .{ std.math.floatMax(f32), -std.math.floatMax(f32) };
    //dim is [num dimensions, x, y, z, time ...]
    for (0..@as(usize, @intCast(img.header.dim[3]))) |z| {
        for (0..@as(usize, @intCast(img.header.dim[2]))) |y| {
            for (0..@as(usize, @intCast(img.header.dim[1]))) |x| {
                const val = try img.getAt4D(x, y, z, 0, false, .{ 0, 0 });
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
const zools = @import("zools");
const t = zools.timer;

test "echo module" {
    print("🧠 nifti1.zig test print\n", .{});
}

test "open and normalize nifti file" {
    const timer_start = t.Click();
    defer t.Stop(timer_start);
    defer print("\n⏰ open and normalize nifti file timer:\n", .{});

    const static = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii";
    var img = try Image.init(static);
    defer img.deinit();
    (&img).printHeader();
    print("\ndatatype: {s}\n", .{DataType.name(img.data_type)});
    print("bytes per voxel: {any}\n", .{img.bytes_per_voxel});

    const mid_x: usize = @divFloor(@as(usize, @intCast(img.header.dim[1])), 2);
    const mid_y: usize = @divFloor(@as(usize, @intCast(img.header.dim[2])), 2);
    const mid_z: usize = @divFloor(@as(usize, @intCast(img.header.dim[3])), 2);
    const mid_t: usize = @divFloor(@as(usize, @intCast(img.header.dim[4])), 2);

    const mid_value = try img.getAt4D(mid_x, mid_y, mid_z, mid_t, false, .{ 0, 0 });

    print("middle value: {any}\n", .{mid_value});

    print("Normalizing\nSetting Min Max\n", .{});
    const minmax = try MinMax3D(img);
    print("Min Max: {any}\n", .{minmax});
    const normalized_mid_value = try img.getAt4D(mid_x, mid_y, mid_z, mid_t, true, minmax);
    print("Normalized mid value: {any}\n", .{normalized_mid_value});
}
