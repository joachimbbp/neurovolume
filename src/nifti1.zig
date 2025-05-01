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
    data: []u8,
    allocator: *const std.mem.Allocator,

    pub fn printHeader(self: *const Image) void {
        std.debug.print("{any}", .{self.header});
    }
    pub fn init(filepath: []const u8) !Image {
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

        return Image{ .header = header_ptr, .data = raw_data, .allocator = allocator };
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
    img.deinit();
}

//convention:
//Types: pascal
//fields: snake
//methods: camel
