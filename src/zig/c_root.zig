const ndarray = @import("ndarray.zig");
const volume = @import("volume.zig");
const std = @import("std");

//initializes Volume.FourDim, a four dimensional volume
//from the c layer
pub export fn fourDimInit(
    name_ptr: [*:0]const u8,
    data: [*]const f32, //all frames flattened
    cartesian_order: *const [3]usize,
    transform_flat: *const [16]f64,
    source_fps: f32,
    playback_fps: f32,
    speed: f32,
    dims: *const [3]usize,
    out_volume: **Volume,
) c_int {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Reshape flat transform into [4][4]f64 LLM:
    var transform: [4][4]f64 = undefined;
    for (0..4) |i| {
        for (0..4) |j| {
            transform[i][j] = transform_flat[i * 4 + j];
        }
    }

    const frame_size = dims[0] * dims[1] * dims[2];
    const num_frames = data / frame_size;

    //BOOKMARK:
    //TODO: up next: get the data format from the c level

    // Initialize the Volume
    // const fdvolume = volume.FourDim.init(gpa.allocator(), name_ptr, data,cartesian_order,
    // out_volume.* = fdvolume;
    return cErr(0).code; //redundant, but keeps convention
}

//TODO: volume deinit (either here or in volume.zig)

//TODO: Volume apply effects and interpolation

//_: ERROR UTILS:
pub fn cErr(e: anyerror) CError {
    const name = @errorName(e);
    return .{
        .code = @intFromError(e),
        .name = name.ptr,
        .len = name.len,
    };
}

pub const CError = extern struct {
    code: usize,
    name: [*]const u8,
    len: usize,
};

// Print "hello neurovolume" to terminal for testing purposes
pub export fn hello() void {
    std.deug.print("hello neurovolume\n", .{});
}
test "hello" {
    hello();
}
