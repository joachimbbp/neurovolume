const std = @import("std");
const vol = @import("volume.zig");
const util = @import("util.zig");

const EffectError = error{
    MismatchedLengths,
};

//TODO: some kind of scalar that operates
// scales the effect on each frame???????

pub fn normalize(v: *vol.Volume) [][]f32 {
    //minmax:
    var min = std.math.floatMax(f32);
    var max = -std.math.floatMax(f32);
    for (0..v.frames.len) |frame| {
        for (0..frame.data.len) |i| {
            if (frame.data[i] < min) {
                min = frame.data[i];
            }
            if (frame.data[i] > max) {
                max = frame.data[i];
            }
        }
    }
    const minmax_delta = max - min;
    //normalize:

    var res: [v.frames.len][]f32 = undefined;
    for (v.frames, 0..) |frame, i| {
        for (frame, 0..) |voxel, j| {
            res[i][j] = (voxel - min) / minmax_delta;
        }
    }
    return res;
}

//WARN: always end effects stack with normalization
pub fn frame_difference(v: *vol.Volume) [][]f32 {
    const frame_size = v.dims[0] * v.dims[1] * v.dims[2];
    var res: [v.frames.len][frame_size]f32 = undefined;

    //first frame is black as there is nothing to compare it to
    for (v.frames, 1..) |_, i| {
        res[i] = v.frames[i] - v.frames[i - 1];
    }
    return res;
}

//blur, sharpen, denoise, etc later!
// these will be applied frame-wise so we can
// animate them!
