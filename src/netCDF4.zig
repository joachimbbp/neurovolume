const std = @import("std");
const print = std.debug.print;

//SOURCE: https://support.hdfgroup.org/documentation/hdf5/latest/_f_m_t4.html

const FormatSignature = extern struct { //HDF5 v2
    start: u8, // 137
    magic: [3]u8, // "HDF"
    carriage_return: u8, // 13
    escape_1: u8, // 10
    ctrl_z: u8, // 26
    escape_2: u8, // 10
};

const Superblock = extern struct { //HDF5 v2
    fmt_signature: FormatSignature,
    superblock_version: u8,
    size_of_offsets: u8,
    size_of_lengths: u8,
    _file_consistency_flags: u8, //unused in verion 2

    // from the SOURCE:
    // This value contains the number of bytes used to store addresses in the file. The values for the addresses of objects in the file are offsets relative to a base address, usually the address of the superblock signature. This allows a wrapper to be added after the file is created without invalidating the internal offset locations. This field is present in version 0+ of the superblock.

    base_address: [4]u8,
    superblock_extension_address: u8,
    end_of_file_address: u8,
    root_group_object_header_address: u8,
    superblock_checksum: u8,
};

pub fn load_HDF5_V2(filepath: []const u8) !void {
    const alloc = &std.heap.page_allocator;
    //copying the NIfTI1 alloc pattern, no idea why it's the address of a page_allocator
    const file = try std.fs.cwd().openFile(filepath, .{});
    defer file.close();

    const reader = std.fs.File.deprecatedReader(file);
    const superblock_ptr = try alloc.create(Superblock); //netCDF4 always uses this version of HDF5
    superblock_ptr.* = try reader.readStruct(Superblock);

    print("HDF5FormatSignature: {any}\n", .{superblock_ptr});
}

test "format signature" {
    const test_filepath = "/Users/joachimpfefferkorn/repos/neurovolume/media/netCDF/merg_2025010123_4km-pixel.nc4.nc4";
    try load_HDF5_V2(test_filepath);
}
