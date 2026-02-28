const ndarray = @import("ndarray.zig");
const volume = @import("volume.zig");
const std = @import("std");

//WARN: must mirror SourceFormat in volume.zig

//initializes Volume.FourDim, a four dimensional volume
//from a ndarray
//call source with:
//      c_int(0) #ndarray
//      c_int(1) #nifti1
//returns a ptr to the volume
pub export fn fourDimInitFromNDarray(
    base_name: [*:0]const u8,
    save_folder: [*:0]const u8,
    overwrite: bool,
    source_format: volume.SourceFormat,
    data: [*]const f32, //all frames flattened
    transform_flat: *const [16]f64,
    source_fps: f32,
    playback_fps: f32,
    speed: f32,
    dims: *const [4]usize,
) ?*anyopaque {
    const allocator = std.heap.c_allocator;
    // Reshape flat transform into [4][4]f64 LLM:
    var transform: [4][4]f64 = undefined;
    for (0..4) |i| {
        for (0..4) |j| {
            transform[i][j] = transform_flat[i * 4 + j];
        }
    }

    const frame_size = dims[0] * dims[1] * dims[2];
    const len = frame_size * dims[3];

    const save_config = volume.SaveConfiguration{
        .basename = std.mem.span(base_name),
        .folder = std.mem.span(save_folder),
        .overwrite = overwrite,
    };

    //LLM: advice on heap allocating the volume
    const vol_ptr = allocator.create(volume.FourDim) catch {
        return null;
    };
    vol_ptr.* = volume.FourDim.init(
        allocator,
        std.mem.span(base_name),
        data[0..len],
        source_format,
        transform,
        false,
        source_fps,
        playback_fps,
        speed,
        dims.*,
        save_config,
    ) catch {
        allocator.destroy(vol_ptr); //LLM: caught this potential memory leak and added this line
        return null;
        //HACK: not sure about error handling on Python side
    };
    return vol_ptr;
}

//BOOKMARK: up next: a save function with that takes in the above pointer!

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
    std.debug.print("hello neurovolume\n", .{});
}
test "hello" {
    hello();
}
