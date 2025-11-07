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
};

//_: Zig Library:

// implementation of Jan's increment_cartesian suggestion
pub fn increment_cartesian(
    comptime num_dims: comptime_int,
    cart_coord: *[num_dims]u32, //as VDBs seem to be built around U32s
    dims: [num_dims]usize,
) bool {
    //false if overflow occurs, true if otherwise
    for (0.., dims) |i, di| {
        cart_coord[i] += 1;
        if (cart_coord[i] < di) {
            return true;
        }
        cart_coord[i] = 0;
    }
    return false;
}

fn getValue(
    data: *const []const u8,
    idx: usize, //linear index
    bytes_per_voxel: u16, //NIfTI1 convention, will cover all cases
    comptime SourceType: type,
    comptime ResType: type,
    endianness: std.builtin.Endian,
    num_bytes: u16,
    //Scaling: (set both to 0 if they do not apply)
    slope: ResType,
    intercept: ResType,
    //Normalizing
    normalize: bool,
    minmax: [3]ResType, //min, max, max-min
) ResType {
    const bit_start: usize = idx * @as(usize, @intCast(bytes_per_voxel));
    const bit_end: usize = (idx + 1) * @as(usize, @intCast(bytes_per_voxel));
    const bytes_input = data.*[bit_start..bit_end]; //GPT: dereferencing suggested
    const type_size = @divExact(@typeInfo(SourceType).int.bits, 8); //LLM: suggested
    _ = num_bytes;
    const raw_value: f32 = @floatFromInt(std.mem.readInt(
        SourceType,
        bytes_input[0..type_size],
        endianness,
    ));
    var res_value = raw_value;
    if (slope != 0 and intercept != 0) {
        res_value = slope * raw_value + intercept;
    }

    if (normalize) {
        res_value = (res_value - minmax[0]) / minmax[2];
    }
    return res_value;
}

//returns .{mininmum value, maximum value, difference between max and min}
pub fn MinMax(
    comptime T: type, //must be float for now
    data: *const []const u8,
    bytes_per_voxel: u16, //NIfTI1 convention but should cover all cases
    slope: f32,
    intercept: f32,
) [3]T //min, max, max-min
{
    const num_voxels = data.len / @as(usize, @intCast(bytes_per_voxel)); //LLM:
    var minmax: [3]T = .{
        std.math.floatMax(T),
        -std.math.floatMax(T),
        undefined,
    };

    for (0..num_voxels) |idx| {
        const val = getValue(
            data,
            idx,
            bytes_per_voxel,
            i16,
            T,
            .little,
            2,
            slope,
            intercept,
            false,
            .{ 0, 0, 0 },
        );
        if (val < minmax[0]) {
            minmax[0] = val;
        }
        if (val > minmax[1]) {
            minmax[1] = val;
        }
    }
    minmax[2] = minmax[1] - minmax[0];
    return minmax;
}
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

            while (increment_cartesian(3, &cart, dims)) {
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
                    @floatCast(res_value),
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
                    if (increment_cartesian(3, &cart, dims) == false) {
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
