//_: Interpolation Effects
//TODO:
const vol = @import("volume.zig");
const std = @import("std");

pub fn step_print(v: *vol.Volume) [][]f32 {
    _ = v;
    //result is source frames stretched to output fps stretched to speed

}
pub fn cross_fade(v: *vol.Volume) [][]f32 {
    _ = v;
}

//
// pub const FrameInterpolation = enum {
//     step_print, //use this for no interpolation
//     cross_fade,
// };
