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

pub const Image = extern struct {
    header: Header,
    data_start: *const u8,
    data_len: usize, //data and data_len lets you get the raw data from data[0..data_len]
    //byteToFloat

    pub fn printHeader(self: *const Image) void {
        std.debug.print("{any}", .{self.header});
    }
    pub fn init(filepath: []const u8) !Image {
        //Load File
        const file = try std.fs.cwd().openFile(filepath, .{});
        defer file.close();

        //Load Header
        const reader = file.reader();
        const header = try reader.readStruct(Header); //Perhaps there is better error handling

        //Load Data
        //const c = @as(i32, @intFromFloat(b));
        const vox_offset = @as(u32, @intFromFloat(header.voxOffset)); //@intFromFloat(u32, @intFromFloat(header.voxOffset));

        try file.seekTo(vox_offset);
        const file_size = try file.getEndPos();
        const allocator = std.heap.page_allocator;

        const raw_data = try allocator.alloc(u8, (file_size - vox_offset));
        _ = try file.readAll(raw_data);

        return Image{ .header = header, .data_start = raw_data.ptr, .data_len = raw_data.len };
    }
};

test "open" {
    const static = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii";
    const img = try Image.init(static);
    (&img).printHeader();
}

//convention:
//Types: pascal
//fields: snake
//methods: camel
