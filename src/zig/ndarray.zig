//SOURCE:
//https://numpy.org/doc/stable/dev/internals.html#numpy-internals

const vdb543 = @import("vdb543.zig");
const std = @import("std");
const util = @import("util.zig");
const Volume = @import("volume.zig").Volume;
const constants = @import("constants.zig");

const NdarrayError = error{
    SourceTypeNotSupportedByVDBYet,
};

//Converts a 3D ndarray into a frame and appends it to a volume
//For sequences, iterate through the 4th dimension
// pub fn toFrame(
//     data: [*]f32,
//     frame_num: usize,
//     volume: *Volume,
// ) error{IndexOutOfBounds}!void {
//     if (frame_num >= volume.frame_count) return error.IndexOutOfBounds;
//     const frame_size = volume.dims[0] * volume.dims[1] * volume.dims[2];
//     volume.frames[frame_num] = data[0..frame_size];
// }

//TODO:
//So the above won't work if we interpolate on the zig level!
//

// retrieves voxel data from an cartesian position in an ndarray
pub fn getAtDD(
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
    // var cart = [_]u32{0,0,0,0};
    // BOOKMARK: you're getting sleepy
    // it is almost 2AM
    // but this crazy one liner should work I think
    // like its not that complex
    // TEST IT IN THE MORNING (or whenever you get to this)
    // TODO:
}

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
