//SOURCE:
//https://numpy.org/doc/stable/dev/internals.html#numpy-internals

//DEPRECATED:
//this whole thing might be deprecated
//

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
