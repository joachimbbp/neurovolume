const std = @import("std");
const ndarray = @import("ndarray.zig");
const nifti1 = @import("nifti1.zig");
const util = @import("util.zig");
const vdb543 = @import("vdb543.zig");
const interpolation = @import("interpolation.zig");

const DataFormatError = error{ NotSupportedYet, UnsupportedUsage };
const AccessError = error{IndexOutOBounds};

pub const DataFormat = enum {
    ndarray, //1
    nifti1, //2
};

pub const SaveConfiguration = struct {
    basename: []u8,
    folder: []u8,
    overwrite: bool, // if false, saves version number
};

//Four dimensional volume structure
//nothing is allocated in this struct so no deinit
pub const FourDim = struct {
    base_allocator: std.mem.Allocator,
    name: []const u8,
    data: []const f32,
    cartesian_order: [3]usize, // ndarray: 2 1 0 , nifti1: 0 1 2
    format: DataFormat,
    affine_transform: [4][4]f64, //spatial transform only!
    source_fps: f32,
    playback_fps: f32,
    speed: f32, //0.0 for still, 1.0 for normal, 2.0 for 2X speed
    dims: [4]usize, // x y z t
    frame_size: usize,
    save_config: SaveConfiguration,

    normalizer: util.Normalizer,
    allocator: std.mem.Allocator,

    //ensure ndarray compliance with prep_4D_ndarray
    pub fn init(
        base_allocator: std.mem.Allocator,
        name: []const u8,
        raw_data: []const u8,
        format: DataFormat,
        transform: [4][4]f64,
        normalize: bool,
        source_fps: f32,
        playback_fps: f32,
        speed: f32,
        dims: [4]usize,
        save_config: SaveConfiguration,
    ) !FourDim {
        var slice_f32: []const f32 = undefined;
        var cart_ord: [3]usize = undefined;
        var normalizer: util.Normalizer = undefined;

        switch (format) {
            .ndarray => {
                slice_f32 = std.mem.bytesAsSlice(f32, raw_data);
                cart_ord = .{ 2, 1, 0 };
                if (normalize) {
                    std.debug.print(".ndarrays must be normalized on the Python layer.\nUse the prep_4D_ndarray function", .{});
                    return DataFormatError.UnsupportedUsage;
                }
                normalizer = util.Normalizer.init(false, 0.0, 1.0);
            },
        }

        return .{
            .base_allocator = base_allocator,
            .name = name,
            .data = slice_f32,
            .cartesian_order = cart_ord,
            .format = format,
            .affine_transform = transform,
            .source_fps = source_fps,
            .playback_fps = playback_fps,
            .speed = speed,
            .dims = dims,
            .frame_size = dims[0] * dims[1] * dims[2],
            .save_config = save_config,
            .normalizer = normalizer,
            .allocator = base_allocator,
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
        ) !void {
            switch (mode) {
                .direct => try direct(alloc, vol),
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

    fn saveFrame(
        v: *FourDim,
        frame_num: usize,
        buffer: *std.ArrayList(u8),
    ) !void {

        //LLM: temp save for debug lines
        var buf: [256]u8 = undefined;
        const output_filepath = try std.fmt.bufPrint(&buf, "../../output/tmp_{d}.vdb", .{frame_num});
        //TODO: save logic based off versioning bool etc
        //in save config (to build in FourDim init)
        _ = v;

        const file = try std.fs.cwd().createFile(std.mem.span(output_filepath), .{});

        try file.writeAll(buffer.items);

        defer file.close();
    }

    //extracts a 3D slice of a 4D ndarray to a VDB
    pub fn extractFrame(
        frame_num: usize,
        v: FourDim,
        vdb: *vdb543.VDB,
    ) !void {
        if (frame_num >= v.dims[3]) return AccessError.IndexOutOBounds;
        //Assuming that there aren't headers or things in ndarrays
        //  (I should read the docs I guess)
        const start = frame_num * v.frame_size;
        const end = ((frame_num + 1) * v.frame_size);

        var i: usize = 0;
        var cart = [_]usize{ 0, 0, 0 };
        while (true) {
            try vdb543.setVoxel(
                vdb,
                .{
                    cart[v.cartesian_order[0]],
                    cart[v.cartesian_order[1]],
                    cart[v.cartesian_order[2]],
                },
                v.normalizer.apply(v.data[start..end][i]),
                v.allocator,
            );

            i += 1;
            if (!util.incrementCartesian(
                3,
                &cart,
                .{ v.dims[0], v.dims[1], v.dims[2] },
            )) break;
        }
    }

    // No interpolation
    // Frames from source are written directly
    // to the VDB sequene
    fn direct(
        allocator: std.mem.Allocator,
        v: *FourDim,
        format: DataFormat,
    ) !void {
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        var vdb = try vdb543.VDB.build(arena.allocator());

        var buffer = std.array_list.Managed(u8).init(arena.allocator());

        for (0..v.dims[3]) |n| {
            //TODO: maybe free the memory after its saved to disk?
            switch (format) {
                .ndarray => try extractFrame(n, v, &vdb),
                else => return DataFormatError.NotSupportedYet,
            }

            try vdb543.writeVDB(&buffer, &vdb, v.affine_transform);
            saveFrame(v, n, &buffer);
        }
    }
};
