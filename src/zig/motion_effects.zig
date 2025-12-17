const vol = @import("volume.zig");
const util = @import("util.zig");

const EffectError = error{
    MismatchedLengths,
};

// a minus b, normalized
pub fn frame_difference(a: vol.Frame, b: vol.Frame) !vol.Frame {
    var res_data = []f32;
    const a_len = a.dims[0] * a.dims[1] * a.dims[2];
    const b_len = b.dims[0] * b.dims[1] * b.dims[2];
    if (a_len != b_len) {
        return error.Dimensions;
    }
    for (0..a_len) |i| {
        = a.data[i].* - b.data[i];
//res_data[i] 
        //normalize:
    }

}
