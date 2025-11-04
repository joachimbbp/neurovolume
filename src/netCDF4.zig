const std = @import("std");
const print = std.debug.print;

//SOURCE: https://support.hdfgroup.org/documentation/hdf5/latest/_f_m_t4.html

const FormatSignature = extern struct {
    start: u8, // 137
    magic: [3]u8, // "HDF"
    carriage_return: u8, // 13
    escape_1: u8, // 10
    ctrl_z: u8, // 26
    escape_2: u8, // 10
};

const Superblock = extern struct {
    superblock_version: u8, // = 2
    size_of_offsets: u8, // = 8 (from your output)
    size_of_lengths: u8, // = 8 (from your output)
    file_consistency_flags: u8, // = 0 (from your output)
};

pub const HDF5_V2 = extern struct { //LLM:
    // Format Signature (8 bytes)
    fmt_signature: FormatSignature,
    // Superblock Version 2
    //    superblock: Superblock,
    // Note: Following fields are variable-sized based on size_of_offsets (8 bytes in your case)
    // base_address: u64,
    // superblock_extension_address: u64,
    // end_of_file_address: u64,
    // root_group_object_header_address: u64,
    // superblock_checksum: u32,
};
pub fn load(filepath: []const u8) !void {
    const alloc = &std.heap.page_allocator;
    //copying the NIfTI1 alloc pattern, no idea why it's the address of a page_allocator
    const file = try std.fs.cwd().openFile(filepath, .{});
    defer file.close();

    const reader = std.fs.File.deprecatedReader(file);
    const fmt_sg_ptr = try alloc.create(FormatSignature); //netCDF4 always uses this version of HDF5
    fmt_sg_ptr.* = try reader.readStruct(FormatSignature);

    print("HDF5FormatSignature: {any}\n", .{fmt_sg_ptr});
}

test "format signature" {
    const test_filepath = "/Users/joachimpfefferkorn/repos/neurovolume/media/netCDF/merg_2025010123_4km-pixel.nc4.nc4";
    try load(test_filepath);
}
