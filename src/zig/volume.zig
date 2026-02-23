const std = @import("std");
const ndarray = @import("ndarray.zig");
const nifti1 = @import("nifti1.zig");
const util = @import("util.zig");
const vdb543 = @import("vdb543.zig");
const interpolation = @import("interpolation.zig");

pub const DataFormat = enum {
    ndarray,
    nifti1,
};

pub const SaveConfiguration = struct {
    basename: []u8,
    folder: []u8,
    overwrite: bool, // if false, saves version number
};

pub const FourDim = struct {
    base_allocator: std.mem.Allocator,
    name: []const u8,
    raw_data: []const u8,
    cartesian_order: [3]usize, // ndarray: 2 1 0 , nifti1: 0 1 2
    format: DataFormat,
    transform: [4][4]f64,
    source_fps: f32,
    playback_fps: f32,
    speed: f32, //0.0 for still, 1.0 for normal, 2.0 for 2X speed
    dims: [4]usize, // x y z t
    frame_size: usize,
    save_config: SaveConfiguration,

    pub fn init(
        base_allocator: std.mem.Allocator,
        name: []const u8,
        raw_data: []const u8,
        cartesian_order: [3]usize,
        format: DataFormat,
        transform: [4][4]f64,
        source_fps: f32,
        playback_fps: f32,
        speed: f32,
        dims: [4]usize,
        save_config: SaveConfiguration,
    ) FourDim {
        //LLM: whole function. I didn't want to type this out
        return .{
            .base_allocator = base_allocator,
            .name = name,
            .raw_data = raw_data,
            .cartesian_order = cartesian_order,
            .format = format,
            .transform = transform,
            .source_fps = source_fps,
            .playback_fps = playback_fps,
            .speed = speed,
            .dims = dims,
            .frame_size = dims[0] * dims[1] * dims[2],
            .save_config = save_config,
        };
    }

    pub const InterpolationMode = enum {
        direct,
    };

    //WIP:
    fn buildPath(static: bool, frame: usize, save_config: SaveConfiguration) []const u8 {
        _ = static;
        _ = frame;
        _ = save_config;
        //WARNING: probably shouldn't be a []u8????
        return "HAM/SPAM";
    }

    const Interpolate = struct {
        fn chose(
            alloc: std.mem.Allocator,
            mode: InterpolationMode,
            vol: *FourDim,
            vdb: *vdb543.VDB,
        ) !void {
            switch (mode) {
                .direct => try direct(alloc, vol, vdb),
                //TODO: error handling
            }
            //feeling kinda meh about this pattern
            //it would be nicer if I didn't have to use
            //a separate structure for this
            //like some sort of reflection on the
            //methods on this struct idk
            //TODO:
            //I mean basically you've got the interpolation mode
            //and the source. Both of these effect how you
            //write the vdb to disk and how you access the data
            //(respectively). So there is probably some better patterin in
            //here.
        }
    };

    // No interpolation
    // Frames from source are written directly
    // to the VDB sequene
    fn direct(
        alloc: std.mem.Allocator,
        v: *FourDim,
        format: DataFormat,
    ) !void {
        //WARN: We're working with 4D volumes
        //      it might get weird!

        //BOOKMARK:
    }
};
// pub fn toVDB(
//     self: *Volume,
//     alloc: std.mem.Allocator,
//     save_path: [*:0]const u8,
//     overwrite: bool, //if false, will version file
//     interpolation_mode: InterpolationMode,
// ) !void {
//     var vdb = try vdb543.VDB.build(alloc);
//     //BOOKMARK:
//this is at a good place for  calling separate functions
//based on what interpolation you want
//up next:
//- [ ] finish function with save
//- [ ] test this functionality
//- [ ] add new interpolation modes

//         var buffer = std.array_list.Managed(u8).init(alloc);
//         defer buffer.deinit();
//
//         if (overwrite) {
//             const file = try std.fs.cwd().createFile(save_path, .{});
//
//             try file.writeAll(buffer.items);
//             defer file.close();
//         } else {
//             std.debug.print("file versioning not implemented yet!\n file not saved\n", .{});
//         }
//     }
// }
// }
//
