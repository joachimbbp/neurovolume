const std = @import("std");

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
    bytes_to_float: *const fn ([]u8) f32,

    const Errors = error{
        UnsupportedBitPix,
    };

    fn btf1(b: []u8) f32 {
        return @floatFromInt(b[0]);
    }
    fn btf2(b: []u8) f32 {
        const raw = std.mem.readInt(u16, b[0..2], .little);
        const signed: i16 = @bitCast(raw);
        return @floatFromInt(signed);
    }
    fn btf4(b: []u8) f32 {
        const raw = std.mem.readInt(u32, b[0..4], .little);
        const signed: i32 = @bitCast(raw);
        return @floatFromInt(signed);
    }
    fn btf8(b: []u8) f32 {
        const raw = std.mem.readInt(u64, b[0..8], .little);
        const signed: i64 = @bitCast(raw);
        return @floatFromInt(signed);
    }

    pub fn printHeader(self: *const Image) void {
        std.debug.print("{any}", .{self.header});
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

        //Build byte to float
        const bytes_to_float: *const fn ([]u8) f32 = switch (header_ptr.*.bitpix) {
            //bitPix / 8 (the bit depth) corresponds to the proper amount of bytes
            //to convert to a float
            8 => &btf1,
            16 => &btf2,
            32 => &btf4,
            64 => &btf8,
            else => {
                std.debug.print("Unsupported bit pix: {}\n", .{header_ptr.*.bitpix});
                return error.UnsupportedBitPix;
            },
        };

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

        return Image{ .header = header_ptr, .data = raw_data, .allocator = allocator, .bytes_to_float = bytes_to_float, .data_type = data_type };
    }

    pub fn deinit(self: *const Image) void {
        self.allocator.destroy(self.header);
        self.allocator.free(self.data);
    }
};

test "open" {
    const static = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii";
    const img = try Image.init(static);
    (&img).printHeader();
    std.debug.print("\ndatatype: {s}\n", .{img.data_type});

    img.deinit();
}

//convention:
//Types: pascal
//fields: snake
//methods: camel
