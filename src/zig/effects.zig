const std = @import("std");
const vol = @import("volume.zig");
const util = @import("util.zig");

const EffectError = error{
    MismatchedLengths,
};

pub fn normalize(
    data: []f32,
) []f32 {
    var min = std.math.floatMax(f32);
    var max = -std.math.floatMax(f32);
    for (0..data.len) |i| {
        if (data[i] < min) {
            min = data[i];
        }
        if (data[i] > max) {
            max = data[i];
        }
    }
    const minmax_delta = max - min;
    var res: [data.len]f32 = undefined;
    for (0..data.len) |i| {
        res[i] = (data[i] - min) / minmax_delta;
    }
    return data;
}

// a minus b
// reccomend normalizing after
pub fn frame_difference(v: vol.Volume) !vol.Frame {
    //WIP:
    var res_data = []f32;
    const a_len = a.dims[0] * a.dims[1] * a.dims[2];
    const b_len = b.dims[0] * b.dims[1] * b.dims[2];
    if (a_len != b_len) {
        return error.Dimensions;
    }
    for (0..a_len) |i| {
        res_data[i] = a.data[i].* - b.data[i].*;
    }

    //res_data[i]
    //normalize:

}

//blur, sharpen, denoise, etc later!
// these will be applied frame-wise so we can
// animate them!
