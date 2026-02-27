//SOURCE:
//https://numpy.org/doc/stable/dev/internals.html#numpy-internals

const vdb543 = @import("vdb543.zig");
const std = @import("std");
const util = @import("util.zig");
const volume = @import("volume.zig");
const constants = @import("constants.zig");

const NdarrayError = error{
    SourceTypeNotSupportedByVDBYet,
    IndexOutOBounds,
};

// retrieves voxel data from an cartesian position in an ndarray
//TODO:
//this will become useful once we start doing
//frame interpoloation (see lab notes page 1)
//might have to get integrated into extractFrame
pub fn getAt4D(
    comptime SourceType: type,
    comptime OutputType: type,
    source_data: []const SourceType,
    cart_idx: usize,
    normalizer: util.Normalizer,
) !OutputType {
    //TODO: remove this check once arbitrary types are
    //supported in vdb543.zig
    if (OutputType != f32) {
        return NdarrayError.SourceTypeNotSupportedByVDBYet;
    }
    return normalizer.apply(source_data[cart_idx]);
}

//extracts a 3D slice of a 4D ndarray to a VDB
pub fn extractFrame(
    frame_num: usize,
    v: volume.FourDim,
    vdb: *vdb543.VDB,
) !void {
    const slice = std.mem.bytesAsSlice(f32, v.raw_data);

    if (frame_num >= v.dims[3]) return NdarrayError.IndexOutOBounds;
    //Assuming that there aren't headers or things in ndarrays
    //  (I should read the docs I guess)
    const start = frame_num * v.frame_size;
    const end = ((frame_num + 1) * v.frame_size);

    var i: usize = 0;
    var cart = [_]usize{ 0, 0, 0 };
    while (true) {
        try vdb543.setVoxel(
            vdb,
            .{
                cart[v.cartesian_order[0]],
                cart[v.cartesian_order[1]],
                cart[v.cartesian_order[2]],
            },
            v.normalizer.apply(slice[start..end][i]),
            v.allocator,
        );

        i += 1;
        if (!util.incrementCartesian(
            3,
            &cart,
            .{ v.dims[0], v.dims[1], v.dims[2] },
        )) break;
    }
}
