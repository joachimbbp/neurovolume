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

    const Errors = error{
        UnsupportedBitPix,
    };
    const Bytes = enum(i16) {
        one = 8,
        two = 16,
        four = 32,
        eight = 64,
    };

    fn btf(comptime bytes: Bytes, b: *const [@intFromEnum(bytes)]u8) f32 {
        const Int = @Type(.{ .int = .{ .bits = @intFromEnum(bytes), .signedness = .signed } });
        const signed = std.mem.readInt(Int, b, .little);
        return @floatFromInt(signed);
    }
    pub fn bytesToFloat(self: *const Image, bytes: []const u8) !f32 {
        const num_bytes = std.meta.intToEnum(Bytes, self.header.bitpix) catch return error.UnsupportedBitPix;
        switch (num_bytes) {
            inline else => |b| return btf(b, bytes[0..@intFromEnum(b)]),
        }
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

        return Image{ .header = header_ptr, .data = raw_data, .allocator = allocator, .data_type = data_type };
    }

    pub fn deinit(self: *const Image) void {
        //TODO everything else
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
