//SOURCE:
//https://numpy.org/doc/stable/dev/internals.html#numpy-internals

const vdb543 = @import("vdb543.zig");
const std = @import("std");
const util = @import("util.zig");
const Volume = @import("volume.zig").Volume;
const constants = @import("constants.zig");

const NdarrayError = error{
    SourceTypeNotSupportedByVDBYet,
    IndexOutOBounds,
};

// retrieves voxel data from an cartesian position in an ndarray
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

pub fn get3DFrameFrom4D(
    data: [*]f32,
    frame_num: usize,
    v: Volume.FourDim,
    vdb: *vdb543.VDB,
    normalizer: util.Normalizer,
    allocator: std.mem.Allocator,
) !void {
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
            normalizer.apply(data[start..end][i]),
            allocator,
        );

        i += 1;
        if (!util.incrementCartesian(
            3,
            &cart,
            .{ v.dims[0], v.dims[1], v.dims[2] },
        )) break;
    }
}

//     volume.frames[frame_num] = data[0..frame_size];
//NOTE:
//so i guess you'll build the VDB here
//then we'll save it on the volume level!

//    comptime num_dims: comptime_int,
// dim_sizes: *const [num_dims]usize,
// cart_idx: usize, //cartesian index
// transpose: [4]usize,
//
// var cart = [num_dims]u32{0} ** num_dims; //LLM: dynamic sizing
// while (util.incrementCartesian(cart.len, &cart, dim_sizes)) {
//
//
// }
// This is inverted, the while loop is what iterates
// through this. oyu just have to set the pixel
// while(util.incrementCartesian(4, &cart, dim_sizes)) {
//
//
// }
