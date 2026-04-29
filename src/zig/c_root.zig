const volume = @import("volume.zig");
const sequence = @import("sequence.zig");
const std = @import("std");
const vdb543 = @import("vdb543.zig");

//make sure even unused stuff from volume is testsed:
test {
    // std.testing.refAllDecls(volume);
    std.testing.refAllDecls(sequence);
}

// WIP: moving threeDim to use grids

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
    std.debug.print("hello neurovolume! Sparse time! Multi grids!\n", .{});
}
test "hello" {
    hello();
}

// 100% AI LLM copypasta (eventually a heuristic should translate this!):
// ============================================================================
// Grid C ABI
// ============================================================================

// Initializes a volume.Grid (does NOT populate it — call populateGrid next).
// source_format:
//      c_int(0) #ndarray
//      c_int(1) #nifti1
// returns a ptr to the Grid (or null on failure)
pub export fn initGrid(
    name: [*:0]const u8,
    source_format: volume.SourceFormat,
    cartesian_order: *const [3]usize,
    transform_flat: *const [16]f64,
    normalize: bool,
    dims: *const [3]usize,
    prune: ?*const f32,
) ?*anyopaque {
    const prune_val: ?f32 = if (prune) |p| p.* else null;

    const allocator = std.heap.c_allocator;

    // Reshape flat transform into [4][4]f64 LLM:
    var transform: [4][4]f64 = undefined;
    for (0..4) |i| {
        for (0..4) |j| {
            transform[i][j] = transform_flat[i * 4 + j];
        }
    }

    // Dupe the name so the struct owns it past the Python call lifetime
    const name_owned = allocator.dupe(u8, std.mem.span(name)) catch return null;

    const grid_ptr = allocator.create(volume.Grid) catch {
        allocator.free(name_owned);
        return null;
    };

    grid_ptr.* = volume.Grid.init(
        allocator,
        name_owned,
        cartesian_order.*,
        source_format,
        transform,
        normalize,
        dims.*,
        prune_val,
    ) catch {
        allocator.free(name_owned);
        allocator.destroy(grid_ptr);
        return null;
    };

    return grid_ptr;
}

// Populates the Grid's VDB with voxel data.
// data: all voxels flattened, length must equal dims[0] * dims[1] * dims[2]
pub export fn populateGrid(
    ptr: ?*anyopaque,
    data: [*]const f32,
) usize {
    if (ptr) |p| { //LLM: unwrapping pattern
        const grid_ptr: *volume.Grid = @ptrCast(@alignCast(p)); //LLM: casting pattern
        const len = grid_ptr.dims[0] * grid_ptr.dims[1] * grid_ptr.dims[2];
        grid_ptr.populate(data[0..len], null) catch |e| {
            return cErr(e).code;
        };
    } //else would be a null ptr
    return 0;
}

pub export fn deinitGrid(ptr: ?*anyopaque) void {
    const allocator = std.heap.c_allocator;
    if (ptr) |p| { //LLM: unwrapping pattern
        const grid_ptr: *volume.Grid = @ptrCast(@alignCast(p)); //LLM: casting pattern
        grid_ptr.deinit();
        allocator.free(grid_ptr.name);
        allocator.destroy(grid_ptr);
    }
}

// ============================================================================
// Vol C ABI
// ============================================================================

// Initializes a volume.Vol from an array of Grid pointers (from initGrid,
// each one already populated via populateGrid).
// grid_ptrs: pointer to an array of ?*anyopaque, each pointing to a volume.Grid
// grid_count: number of grids in grid_ptrs
// returns a ptr to the Vol (or null on failure)
//
// NOTE: the referenced volume.Grid objects must outlive the Vol — do NOT call
// deinitGrid on any of them until after saveVol + deinitVol are done.
pub export fn initVol(
    basename: [*:0]const u8,
    save_folder: [*:0]const u8,
    overwrite: bool,
    grid_ptrs: [*]const ?*anyopaque,
    grid_count: usize,
) ?*anyopaque {
    const allocator = std.heap.c_allocator;

    // Dupe strings so the struct owns them past the Python call lifetime
    const basename_owned = allocator.dupe(u8, std.mem.span(basename)) catch return null;
    const folder_owned = allocator.dupe(u8, std.mem.span(save_folder)) catch {
        allocator.free(basename_owned);
        return null;
    };

    // Build an owned slice of vdb543.Grid values pulled off each volume.Grid
    const grids = allocator.alloc(vdb543.Grid, grid_count) catch {
        allocator.free(basename_owned);
        allocator.free(folder_owned);
        return null;
    };

    for (0..grid_count) |i| {
        const gp = grid_ptrs[i] orelse {
            allocator.free(grids);
            allocator.free(basename_owned);
            allocator.free(folder_owned);
            return null;
        };
        const grid_ptr: *volume.Grid = @ptrCast(@alignCast(gp)); //LLM: casting pattern
        // populateGrid must have been called already, so .grid is non-null
        const inner = grid_ptr.grid orelse {
            allocator.free(grids);
            allocator.free(basename_owned);
            allocator.free(folder_owned);
            return null;
        };
        grids[i] = inner;
    }

    const vol_ptr = allocator.create(volume.Vol) catch {
        allocator.free(grids);
        allocator.free(basename_owned);
        allocator.free(folder_owned);
        return null;
    };

    vol_ptr.* = volume.Vol{
        .grids = grids,
        .save_config = volume.SaveConfiguration{
            .basename = basename_owned,
            .folder = folder_owned,
            .overwrite = overwrite,
        },
    };

    return vol_ptr;
}

pub export fn deinitVol(ptr: ?*anyopaque) void {
    const allocator = std.heap.c_allocator;
    if (ptr) |p| { //LLM: unwrapping pattern
        const vol_ptr: *volume.Vol = @ptrCast(@alignCast(p)); //LLM: casting pattern
        allocator.free(vol_ptr.grids);
        allocator.free(vol_ptr.save_config.basename);
        allocator.free(vol_ptr.save_config.folder);
        allocator.destroy(vol_ptr);
    }
}

pub export fn saveVol(ptr: ?*anyopaque) usize {
    if (ptr) |p| { //LLM: unwrapping pattern
        const vol_ptr: *volume.Vol = @ptrCast(@alignCast(p)); //LLM: casting pattern
        vol_ptr.save(null) catch |e| {
            return cErr(e).code;
        };
    } //else would be a null ptr
    return 0;
}
// ============================================================================
// Channel C ABI
// ============================================================================

// Initializes a sequence.Channel as a BORROWING view over caller-owned memory.
// The caller (Python wrapper) MUST keep `name` and `data` alive for the
// lifetime of the Channel — typically by holding references to the original
// numpy array and encoded bytes object on the Python Channel instance.
//
// data: all voxels flattened across all frames, length must equal
//       dims[0] * dims[1] * dims[2] * dims[3] (T * X * Y * Z)
// dims: [T, X, Y, Z]
// returns a ptr to the Channel (or null on failure)
pub export fn initChannel(
    name: [*:0]const u8,
    data: [*]const f32,
    frame_cartesian_order: *const [3]usize,
    source_format: volume.SourceFormat,
    transform_flat: *const [16]f64,
    dims: *const [4]usize,
    prune: ?*const f32,
    num_frames: usize,
) ?*anyopaque {
    const allocator = std.heap.c_allocator;
    const prune_val: ?f32 = if (prune) |p| p.* else null;

    // Reshape flat transform into [4][4]f64
    var transform: [4][4]f64 = undefined;
    for (0..4) |i| {
        for (0..4) |j| {
            transform[i][j] = transform_flat[i * 4 + j];
        }
    }

    // Borrow name and data — no dupes. Python holds the lifetime.
    const name_borrowed = std.mem.span(name);
    const total_len = dims[0] * dims[1] * dims[2] * dims[3];
    const data_borrowed = data[0..total_len];

    const channel_ptr = allocator.create(sequence.Channel) catch return null;

    channel_ptr.* = sequence.Channel.init(
        allocator,
        name_borrowed,
        data_borrowed,
        frame_cartesian_order.*,
        source_format,
        transform,
        dims.*,
        prune_val,
        num_frames,
    ) catch {
        allocator.destroy(channel_ptr);
        return null;
    };

    return channel_ptr;
}

pub export fn deinitChannel(ptr: ?*anyopaque) void {
    const allocator = std.heap.c_allocator;
    if (ptr) |p| {
        const channel_ptr: *sequence.Channel = @ptrCast(@alignCast(p));
        // No internal frees — Channel borrows everything. Just drop the box.
        allocator.destroy(channel_ptr);
    }
}

// ============================================================================
// Sequence C ABI
// ============================================================================

// Initializes a sequence.Sequence from an array of Channel pointers.
// channel_ptrs: pointer to an array of ?*anyopaque, each pointing to a
//               sequence.Channel created by initChannel
// channel_count: number of channels in channel_ptrs
//
// NOTE: the referenced Channel objects must outlive the Sequence — the
// Python wrapper enforces this by holding references to the Channel objects
// on the Python Sequence instance.
//
// The basename and save_folder strings must also outlive the Sequence;
// the Python wrapper holds the encoded bytes for that purpose.
pub export fn initSequence(
    basename: [*:0]const u8,
    save_folder: [*:0]const u8,
    overwrite: bool,
    channel_ptrs: [*]const ?*anyopaque,
    channel_count: usize,
) ?*anyopaque {
    const allocator = std.heap.c_allocator;

    // Allocate the channels slice — this IS owned by the C layer because
    // it's a fresh array of pointers we built, not something the caller
    // gave us directly.
    const channels = allocator.alloc(*sequence.Channel, channel_count) catch return null;

    for (0..channel_count) |i| {
        const cp = channel_ptrs[i] orelse {
            allocator.free(channels);
            return null;
        };
        const channel_ptr: *sequence.Channel = @ptrCast(@alignCast(cp));
        channels[i] = channel_ptr;
    }

    const seq_ptr = allocator.create(sequence.Sequence) catch {
        allocator.free(channels);
        return null;
    };

    seq_ptr.* = sequence.Sequence{
        .channels = channels,
        .save_config = volume.SaveConfiguration{
            .basename = std.mem.span(basename),
            .folder = std.mem.span(save_folder),
            .overwrite = overwrite,
        },
    };

    return seq_ptr;
}

pub export fn deinitSequence(ptr: ?*anyopaque) void {
    const allocator = std.heap.c_allocator;
    if (ptr) |p| {
        const seq_ptr: *sequence.Sequence = @ptrCast(@alignCast(p));
        // Only free what the C layer allocated: the channels pointer slice.
        // Strings are borrowed from Python, channel objects are borrowed too.
        allocator.free(seq_ptr.channels);
        allocator.destroy(seq_ptr);
    }
}

pub export fn saveSequence(ptr: ?*anyopaque) usize {
    if (ptr) |p| {
        const seq_ptr: *sequence.Sequence = @ptrCast(@alignCast(p));
        seq_ptr.save() catch |e| {
            return cErr(e).code;
        };
    }
    return 0;
}
