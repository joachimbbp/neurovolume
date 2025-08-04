const std = @import("std");
const print = std.debug.print;
const AccessError = error{
    UnsupportedByteNumber,
};

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
pub const Image = struct { //not sure why this was originally an extern struct?
    header: *const Header,
    data: []const u8,
    allocator: *const std.mem.Allocator,
    data_type: []const u8,
    bytes_per_voxel: i16,

    pub fn getAt4D(self: *const Image, pos: [4]usize) !f32 {
        const nx: usize = @intCast(self.header.dim[1]);
        const ny: usize = @intCast(self.header.dim[2]);
        const nz: usize = @intCast(self.header.dim[3]);
        print("nx: {d} ny: {d} nz: {d}\n position: {d}\n", .{ nx, ny, nz, pos });

        const idx: usize = pos[3] * nx * ny * nz + pos[2] * nx * ny + pos[1] * nx + pos[0];

        const bit_start: usize = idx * @as(usize, @intCast(self.bytes_per_voxel));
        const bit_end: usize = (idx + 1) * @as(usize, @intCast(self.bytes_per_voxel));

        print("index : {d} bit start: {d} bit end: {d}\n", .{ idx, bit_start, bit_end });
        print("raw data len: {d}\n", .{self.data.len});
        const raw_value = switch (self.bytes_per_voxel) {
            2 => btf2(self.data[bit_start..bit_end]),
            //TODO: all of the other byte to float functions!
            else => return AccessError.UnsupportedByteNumber,
        };
        if (self.header.sclSlope != 0) {
            return self.header.sclSlope * raw_value + self.header.sclInter;
        } else {
            return raw_value;
        }
    }

    pub fn printHeader(self: *const Image) void {
        print("{any}", .{self.header});
    }

    pub fn init(filepath: []const u8) anyerror!Image {
        const allocator = &std.heap.page_allocator;
        //Load File
        const file = try std.fs.cwd().openFile(filepath, .{});
        defer file.close();

        //Load Header
        const reader = file.reader();
        const header_ptr = try allocator.create(Header);
        header_ptr.* = try reader.readStruct(Header);

        //Load Data
        const vox_offset = @as(u32, @intFromFloat(header_ptr.voxOffset));
        try file.seekTo(vox_offset);
        const file_size = try file.getEndPos();

        const raw_data = try allocator.alloc(u8, (file_size - vox_offset));
        _ = try file.readAll(raw_data);

        //datatype
        const data_type: []const u8 = switch (header_ptr.*.datatype) {
            0 => "unknown",
            1 => "bool",
            2 => "unsigned char",
            4 => "signed short",
            8 => "signed int",
            16 => "float",
            32 => "complex",
            64 => "double",
            128 => "rgb",
            255 => "all",
            256 => "signed char",
            512 => "unsigned short",
            768 => "unsigned int",
            1024 => "long long",
            1280 => "unsigned long long",
            1536 => "long double",
            1792 => "double pair",
            2048 => "long double pair",
            2304 => "rgba",
            else => "unknown",
        };
        const bytes_per_voxel = @divTrunc(header_ptr.*.bitpix, 8);
        return Image{ .header = header_ptr, .data = raw_data, .allocator = allocator, .data_type = data_type, .bytes_per_voxel = bytes_per_voxel };
    }

    pub fn deinit(self: *const Image) void {
        //TODO: everything else
        //why did robbie put this as destroy for one and free for the other?
        self.allocator.destroy(self.header);
        self.allocator.free(self.data);
    }
};

//Byte to float functions
fn btf2(bytes: []const u8) f32 {
    //This was GPT suggested *but* I checked through the docs and it *seems* correct
    const value = std.mem.readInt(u16, bytes[0..2], .little);
    return @floatFromInt(value); //@as(f32, @floatCast(value));
}

test "open" {
    const static = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii";
    const img = try Image.init(static);
    defer img.deinit();
    (&img).printHeader();
    print("\ndatatype: {s}\n", .{img.data_type});

    const mid_x: usize = @divFloor(@as(usize, @intCast(img.header.dim[1])), 2);
    const mid_y: usize = @divFloor(@as(usize, @intCast(img.header.dim[2])), 2);
    const mid_z: usize = @divFloor(@as(usize, @intCast(img.header.dim[3])), 2);
    const mid_t: usize = @divFloor(@as(usize, @intCast(img.header.dim[4])), 2);

    const mid_value = try img.getAt4D([4]usize{ mid_x, mid_y, mid_z, mid_t });

    print("middle value: {d}\n", .{mid_value});
}

//convention:
//Types: pascal
//fields: snake
//methods: camel
