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

// retrieves voxel data from an x y z t position in an ndarray
// note: no normaliziation functionality (for now). Do that on the Python level.
pub fn getAt4D(
    comptime SourceType: type,
    comptime OutputType: type,
    source_data: []const SourceType,
    xpos: usize,
    ypos: usize,
    zpos: usize,
    tpos: usize,
    normalizer: util.Normalizer,
) !OutputType {
    //WARNING: the VDB writer currently only supports f32
    //TODO: remove this check once arbitrary types are
    //supported in vdb543.zig
    if (OutputType != f32) {
        return NdarrayError.SourceTypeNotSupportedByVDBYet;
    }
    //BOOKMARK: let's pick it up here (see lab notes if your lost)
}
