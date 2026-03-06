const ndarray = @import("ndarray.zig");
const volume = @import("volume.zig");
const std = @import("std");

//WARN: must mirror SourceFormat in volume.zig

//initializes Volume.FourDim, a four dimensional volume
//from an ndarray
//call source with:
//      c_int(0) #ndarray
//      c_int(1) #nifti1
//returns a ptr to the volume
pub export fn initFourDim(
    base_name: [*:0]const u8,
    save_folder: [*:0]const u8,
    overwrite: bool,
    source_format: volume.SourceFormat,
    data: [*]const f32, //all frames flattened
    cartesian_order: *const [3]usize, //usually 0 1 2
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

    // Dupe strings so the struct owns them past the Python call lifetime
    const basename_owned = allocator.dupe(u8, std.mem.span(base_name)) catch return null;
    const folder_owned = allocator.dupe(u8, std.mem.span(save_folder)) catch {
        allocator.free(basename_owned);
        return null;
    };

    const save_config = volume.SaveConfiguration{
        .basename = basename_owned,
        .folder = folder_owned,
        .overwrite = overwrite,
    };

    const vol_ptr = allocator.create(volume.FourDim) catch {
        allocator.free(basename_owned);
        allocator.free(folder_owned);
        return null;
    };
    vol_ptr.* = volume.FourDim.init(
        basename_owned,
        data[0..len],
        cartesian_order.*,
        source_format,
        transform,
        false,
        source_fps,
        playback_fps,
        speed,
        dims.*,
        save_config,
    ) catch {
        allocator.free(basename_owned);
        allocator.free(folder_owned);
        allocator.destroy(vol_ptr);
        return null;
    };
    return vol_ptr;
}

pub export fn deinitFourDim(ptr: ?*anyopaque) void {
    const allocator = std.heap.c_allocator;
    if (ptr) |p| {
        const vol_ptr: *volume.FourDim = @ptrCast(@alignCast(p));
        allocator.free(vol_ptr.save_config.basename);
        allocator.free(vol_ptr.save_config.folder);
        allocator.destroy(vol_ptr);
    }
}

pub export fn saveFourDim(
    ptr: ?*anyopaque,
    interpolation_mode: c_int, //0 for direct
) usize {
    if (ptr) |p| { //LLM: unwrapping pattern
        const vol_ptr: *volume.FourDim = @ptrCast(@alignCast(p));
        vol_ptr.save(@as(volume.InterpolationMode, @enumFromInt(interpolation_mode))) catch |e| {
            return cErr(e).code;
        }; //LLM: casting pattern
    } //else would be a null ptr
    return 0;
}

//LLM: claude wrote this function
pub export fn initThreeDim(
    base_name: [*:0]const u8,
    save_folder: [*:0]const u8,
    overwrite: bool,
    source_format: volume.SourceFormat,
    data: [*]const f32,
    cartesian_order: *const [3]usize,
    transform_flat: *const [16]f64,
    dims: *const [3]usize,
) ?*anyopaque {
    const allocator = std.heap.c_allocator;
    var transform: [4][4]f64 = undefined;
    for (0..4) |i| {
        for (0..4) |j| {
            transform[i][j] = transform_flat[i * 4 + j];
        }
    }

    const len = dims[0] * dims[1] * dims[2];

    // Dupe strings so the struct owns them past the Python call lifetime
    const basename_owned = allocator.dupe(u8, std.mem.span(base_name)) catch return null;
    const folder_owned = allocator.dupe(u8, std.mem.span(save_folder)) catch {
        allocator.free(basename_owned);
        return null;
    };

    const save_config = volume.SaveConfiguration{
        .basename = basename_owned,
        .folder = folder_owned,
        .overwrite = overwrite,
    };

    const vol_ptr = allocator.create(volume.ThreeDim) catch {
        allocator.free(basename_owned);
        allocator.free(folder_owned);
        return null;
    };
    vol_ptr.* = volume.ThreeDim.init(
        basename_owned,
        data[0..len],
        cartesian_order.*,
        source_format,
        transform,
        false,
        dims.*,
        save_config,
    ) catch {
        allocator.free(basename_owned);
        allocator.free(folder_owned);
        allocator.destroy(vol_ptr);
        return null;
    };
    return vol_ptr;
}

//LLM: claude wrote this function
pub export fn deinitThreeDim(ptr: ?*anyopaque) void {
    const allocator = std.heap.c_allocator;
    if (ptr) |p| {
        const vol_ptr: *volume.ThreeDim = @ptrCast(@alignCast(p));
        allocator.free(vol_ptr.save_config.basename);
        allocator.free(vol_ptr.save_config.folder);
        allocator.destroy(vol_ptr);
    }
}

//LLM: claude wrote this function
pub export fn saveThreeDim(ptr: ?*anyopaque) usize {
    if (ptr) |p| {
        const vol_ptr: *volume.ThreeDim = @ptrCast(@alignCast(p));
        vol_ptr.save() catch |e| {
            return cErr(e).code;
        };
    }
    return 0;
}

//BOOKMARK: up next: a save function with that takes in the above pointer!
//Use the new volume.save() that you are writing rn

//TODO: Volume apply effects and interpolation

//_: ERROR UTILS:
pub fn cErr(e: anyerror) CError {
    const name = @errorName(e);
    return .{
        //TODO: should this be a c_int????
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
