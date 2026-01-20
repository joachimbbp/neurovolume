const vdb543 = @import("vdb543.zig");
const std = @import("std");
const util = @import("util.zig");
const vol = @import("volume.zig");
const constants = @import("constants.zig");

//Converts a 3D ndarray into a frame and appends it to a volume
//For sequences, iterate through the 4th dimension
//on the python level
pub fn toFrame(
    data: *[]f32,
    frame_num: usize,
    volume: *vol.Volume,
) error{IndexOutOfBounds}!void {
    //LLM:
    //TODO: D-c-ify this! Make idiomatic zig, c should jut be in the c-root
    if (frame_num >= volume.frame_count) return error.IndexOutOfBounds;
    const frame_size = volume.dims[0] * volume.dims[1] * volume.dims[2];
    volume.frames[frame_num] = try data[0..frame_size];
}
