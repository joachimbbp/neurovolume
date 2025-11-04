const std = @import("std");
const print = std.debug.print;

//SOURCE: https://support.hdfgroup.org/documentation/hdf5/latest/_f_m_t4.html
pub const HDF5FormatSignature = extern struct {
    start: u8, //expect \211 or 137 in decimal
    magic: [3]u8, //expect HDF
    carraige_return: u8, //expect \r or 13 in decimal
    escape_1: u8, //expect \n or 10 in decimal
    ctrl_z: u8, //expect \032 or 26 in decimal
    escape_2: u8,

    //then superblocks start!
};

pub fn getHDF5(filepath: []const u8) !void {
    const alloc = &std.heap.page_allocator;
    //copying the NIfTI1 alloc pattern, no idea why it's the address of a page_allocator
    const file = try std.fs.cwd().openFile(filepath, .{});
    defer file.close();

    const reader = std.fs.File.deprecatedReader(file);
    const fmt_sg_ptr = try alloc.create(HDF5FormatSignature);
    fmt_sg_ptr.* = try reader.readStruct(HDF5FormatSignature);

    print("HDF5FormatSignature: {any}\n", .{fmt_sg_ptr});
}

test "format signature" {
    const test_filepath = "/Users/joachimpfefferkorn/repos/neurovolume/media/netCDF/merg_2025010123_4km-pixel.nc4.nc4";
    try getHDF5(test_filepath);
}
