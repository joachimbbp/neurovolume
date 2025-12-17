//Zig library root

//_: IMPORTS
const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");
const zip = util.zipPairs;
const rev = util.reverseSlice;
const nifti1 = @import("nifti1.zig");
const vdb543 = @import("vdb543.zig");
const constants = @import("constants.zig");
const save = @import("save.zig");

//_: CONSTS:
const config = @import("config.zig.zon");
const SupportError = error{
    Dimensions,
    Type,
};

//_: Zig Library:

// pub fn saveVDBFrame(

fn getValue( //prbably nifti1 specific!
    data: *const []const u8,
    idx: usize, //linear index
    bytes_per_voxel: u16, //NIfTI1 convention, will cover all cases
    comptime VoxelType: type,
    comptime ResType: type,
    endianness: std.builtin.Endian,
    num_bytes: u16,
    //Scaling: set slope to 1 and int to 0 to have them not apply
    slope: ResType,
    intercept: ResType,
    //Normalizing
    normalize: bool,
    minmax: [3]ResType, //min, max, max-min
) ResType {
    const bit_start: usize = idx * @as(usize, @intCast(bytes_per_voxel));
    const bit_end: usize = (idx + 1) * @as(usize, @intCast(bytes_per_voxel));
    const bytes_input = data.*[bit_start..bit_end]; //GPT: dereferencing suggested
    const type_size = @divExact(@typeInfo(VoxelType).int.bits, 8); //LLM: suggested
    _ = num_bytes;
    const raw_value: f32 = @floatFromInt(std.mem.readInt(
        VoxelType,
        bytes_input[0..type_size],
        endianness,
    ));
    var res_value = raw_value;
    if (slope != 1 or intercept != 0) { //wouldn't change res_value
        res_value = slope * raw_value + intercept;
    }

    if (normalize) {
        res_value = (res_value - minmax[0]) / minmax[2];
    }
    return res_value;
}

//returns .{mininmum value, maximum value, difference between max and min}

// Returns path to VDB file (or folder containing sequence if fMRI)
pub fn nifti1ToVDB(
    nifti_filepath: []const u8,
    output_dir: []const u8,
    normalize: bool,
    arena_alloc: std.mem.Allocator,
) ![]const u8 {
    const img = try nifti1.Image.init(nifti_filepath);
    defer img.deinit();
    const hdr = try nifti1.getHeader(nifti_filepath);
    const minmax = MinMax(
        f32,
        &img.data,
        img.bytes_per_voxel,
        hdr.sclSlope,
        hdr.sclInter,
    );
    //output folder / new filename / framename_0
    var n_split = std.mem.splitBackwardsSequence(u8, nifti_filepath, "/");
    var name_split = std.mem.splitBackwardsSequence(u8, n_split.first(), ".");
    const ext = name_split.first();
    _ = ext;
    const basename = name_split.rest();
    const base_seq_folder = try std.fmt.allocPrint(arena_alloc, "{s}/{s}", .{ output_dir, basename });
    var filepath: []const u8 = undefined;

    var cart = [_]u32{ 0, 0, 0 };
    var idx: usize = 0;
    const dims: [3]usize = .{
        @intCast(hdr.dim[1]),
        @intCast(hdr.dim[2]),
        @intCast(hdr.dim[3]),
    };

    switch (img.header.dim[0]) {
        //_:Static Image
        3 => {
            const transform = try nifti1.getTransform(hdr.*);
            var buffer = std.array_list.Managed(u8).init(arena_alloc);
            defer buffer.deinit();
            var vdb = try vdb543.VDB.build(arena_alloc);

            while (incrementCartesian(3, &cart, &dims)) {
                idx += 1;
                const res_value = getValue(
                    &img.data,
                    idx,
                    img.bytes_per_voxel,
                    i16,
                    f32,
                    .little,
                    img.bytes_per_voxel,
                    hdr.sclSlope,
                    hdr.sclInter,
                    normalize,
                    minmax,
                );
                try vdb543.setVoxel(
                    &vdb,
                    .{ cart[0], cart[1], cart[2] },
                    res_value,
                    arena_alloc,
                );
            }

            //ROBOT: Claude sonet 4.5 suggested this:
            if (std.fs.path.dirname(base_seq_folder)) |dir_path| {
                try std.fs.cwd().makePath(dir_path);
            }

            const frame_path = try std.fmt.allocPrint(
                arena_alloc,
                "{[dir]s}/{[bn]s}.vdb",
                .{ .dir = output_dir, .bn = basename },
            );

            const versioned_vdb_filepath = try vdb543.writeFrame(
                &buffer,
                &vdb,
                frame_path,
                arena_alloc,
                transform,
            );
            filepath = versioned_vdb_filepath.items;
        },

        //_: Time Series
        4 => {
            const transform = constants.IdentityMatrix4x4;
            //FIX: native transform doesn't work with bold as of right now!
            const vdb_seq_folder = try save.versionFolder(
                base_seq_folder,
                arena_alloc,
            );
            var buf = std.array_list.Managed(u8).init(arena_alloc);
            defer buf.deinit();
            for (vdb_seq_folder.items) |c| {
                try buf.append(c);
            }
            try buf.append(0);
            const vdb_seq_folder_slice: [:0]const u8 = buf.items[0 .. buf.items.len - 1 :0];

            const num_frames: usize = @intCast(img.header.dim[4]);
            const vpf = @as(usize, @intCast(hdr.dim[1])) *
                @as(usize, @intCast(hdr.dim[2])) *
                @as(usize, @intCast(hdr.dim[3])) *
                @as(usize, @intCast(img.bytes_per_voxel));

            const leading_zeros = util.numDigitsShort(@bitCast(img.header.dim[4]));

            for (0..num_frames) |frame| {
                const frame_start = frame * vpf;
                const frame_end = frame_start + vpf;
                const frame_data = img.data[frame_start..frame_end]; //its late, i think exclusive zig?
                var vdb = try vdb543.VDB.build(arena_alloc);

                idx = 0;

                while (true) {
                    if (incrementCartesian(3, &cart, &dims) == false) {
                        break;
                    }
                    idx += 1;
                    const res_value = getValue(
                        &frame_data, //LLM: caught this eroneously left as `img.data`
                        idx,
                        img.bytes_per_voxel,
                        i16,
                        f32,
                        .little,
                        img.bytes_per_voxel,
                        hdr.sclSlope,
                        hdr.sclInter,
                        normalize,
                        minmax,
                    );
                    try vdb543.setVoxel(
                        &vdb,
                        .{
                            @intCast(cart[0]),
                            @intCast(cart[1]),
                            @intCast(cart[2]),
                        },
                        @floatCast(res_value),
                        arena_alloc,
                    );
                }
                const frame_path = try save.elementName(
                    vdb_seq_folder_slice,
                    basename,
                    "vdb",
                    frame,
                    leading_zeros,
                    arena_alloc,
                );

                var buffer = std.array_list.Managed(u8).init(arena_alloc);
                defer buffer.deinit();

                _ = try vdb543.writeFrame(
                    &buffer,
                    &vdb,
                    frame_path,
                    arena_alloc,
                    transform,
                );
            }

            filepath = vdb_seq_folder.items;
        },
        else => {
            std.debug.print("ERROR: {d} unsupported dimension type\n", .{img.header.dim[0]});
            return SupportError.Dimensions;
        },
    }

    return filepath;
}
