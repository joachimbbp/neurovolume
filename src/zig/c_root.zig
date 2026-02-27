const ndarray = @import("ndarray.zig");
const volume = @import("volume.zig");
const std = @import("std");

//WARN: must mirror SourceFormat in volume.zig

//initializes Volume.FourDim, a four dimensional volume
//from a ndarray
//call source with:
//      c_int(0) #ndarray
//      c_int(1) #nifti1
pub export fn fourDimInitFromNDarray(
    name: [*:0]const u8,
    source: volume.SourceFormat,
    data: [*]const f32, //all frames flattened
    transform_flat: *const [16]f64,
    source_fps: f32,
    playback_fps: f32,
    speed: f32,
    dims: *const [4]usize,
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
    const len = frame_size * dims[4];

    const vol = volume.FourDim.init(
        gpa,
        std.mem.span(name),
        data[0..len],
        source,
        transform,
        false,
        source_fps,
        playback_fps,
        speed,
        dims.*,
    ) catch |e| {
        return cErr(e);
    };
    //BOOKMARK: Here is where you'd do the save func
    //will probably need work on volume.zig
    //rewriting the stuff in the Interpolate struct

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
