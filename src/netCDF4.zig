const std = @import("std");
const print = std.debug.print;
const builtin = @import("builtin");
//SOURCE: https://support.hdfgroup.org/documentation/hdf5/latest/_f_m_t4.html

comptime {
    std.debug.assert(builtin.cpu.arch.endian() == .little);
}

const Superblock = extern struct { //HDF5 v2
    //always little endian
    fmt_signature: u64, //0x0a1a0a0d46444889
    superblock_version: u8,
    size_of_offsets: u8,
    size_of_lengths: u8,
    _file_consistency_flags: u8, //unused in verion 2

    // from the SOURCE:
    // This value contains the number of bytes used to store addresses in the file. The values for the addresses of objects in the file are offsets relative to a base address, usually the address of the superblock signature. This allows a wrapper to be added after the file is created without invalidating the internal offset locations. This field is present in version 0+ of the superblock.

    base_address: u64,
    superblock_extension_address: u64,
    end_of_file_address: u64,
    root_group_object_header_address: u64,
    superblock_checksum: u64,
};

pub fn load_HDF5_V2(filepath: []const u8) !void {
    //assuming little endian for now!
    const alloc = &std.heap.page_allocator;
    //copying the NIfTI1 alloc pattern, no idea why it's the address of a page_allocator
    const file = try std.fs.cwd().openFile(filepath, .{});
    defer file.close();

    const reader = std.fs.File.deprecatedReader(file);
    const sb_ptr = try alloc.create(Superblock); //netCDF4 always uses this version of HDF5
    sb_ptr.* = try reader.readStruct(Superblock);

    std.debug.assert(sb_ptr.size_of_offsets == 8); // won't work if it's not 8!
    std.debug.assert(sb_ptr.size_of_lengths == 8);
    std.debug.assert(sb_ptr.superblock_version == 2);
    std.debug.assert(sb_ptr.fmt_signature == 0x0a1a0a0d46444889);
    print("superblock: {any}\n", .{sb_ptr});
    print("base address: {x}\n", .{sb_ptr.base_address});
}

test "format signature" {
    const test_filepath = "/users/joachimpfefferkorn/repos/neurovolume/media/netcdf/merg_2025010123_4km-pixel.nc4.nc4";
    try load_HDF5_V2(test_filepath);
}
