const std = @import("std");
const ndarray = @import("ndarray.zig");
const util = @import("util.zig");
const vdb543 = @import("vdb543.zig");

const DataFormatError = error{ NotSupportedYet, UnsupportedUsage };
const AccessError = error{IndexOutOBounds};

pub const SourceFormat = enum(c_int) {
    ndarray = 0,
    nifti1 = 1,
};

pub const SaveConfiguration = struct {
    basename: []const u8,
    folder: []const u8,
    overwrite: bool, // if false, saves version number
};

//Four dimensional volume structure
//nothing is allocated in this struct so no deinit
pub const FourDim = struct {
    name: []const u8,
    data: []const f32,
    cartesian_order: [3]usize, // ndarray: 0 1 2 (identity, prep_4D_ndarray handles reorder), nifti1: TBD
    source_format: SourceFormat,
    affine_transform: [4][4]f64, //spatial transform only!
    source_fps: f32,
    playback_fps: f32,
    speed: f32, //0.0 for still, 1.0 for normal, 2.0 for 2X speed
    dims: [4]usize, // x y z t
    frame_size: usize,
    save_config: SaveConfiguration,
    normalizer: util.Normalizer,

    //ensure ndarray compliance with prep_4D_ndarray
    pub fn init(
        name: []const u8,
        data: []const f32,
        source_format: SourceFormat,
        transform: [4][4]f64,
        normalize: bool,
        source_fps: f32,
        playback_fps: f32,
        speed: f32,
        dims: [4]usize,
        save_config: SaveConfiguration,
    ) !FourDim {
        var cart_ord: [3]usize = undefined;
        var normalizer: util.Normalizer = undefined;

        switch (source_format) {
            .ndarray => {
                cart_ord = .{ 0, 1, 2 }; // identity: prep_4D_ndarray already handles axis reordering
                if (normalize) {
                    std.debug.print(
                        "FYI: To ensure compliance, use the prep_4D_ndarray function in the python library",
                        .{},
                    );
                    return DataFormatError.UnsupportedUsage;
                }
                normalizer = util.Normalizer.init(false, 0.0, 1.0);
            },
            else => return DataFormatError.NotSupportedYet,
        }

        return .{
            .name = name,
            .data = data,
            .cartesian_order = cart_ord,
            .source_format = source_format,
            .affine_transform = transform,
            .source_fps = source_fps,
            .playback_fps = playback_fps,
            .speed = speed,
            .dims = dims,
            .frame_size = dims[0] * dims[1] * dims[2],
            .save_config = save_config,
            .normalizer = normalizer,
        };
    }

    //WIP:
    fn buildPath(static: bool, frame: usize, save_config: SaveConfiguration) []const u8 {
        _ = static;
        _ = frame;
        _ = save_config;
        //WARNING: probably shouldn't be a []u8????
        return "HAM/SPAM";
    }

    fn saveFrame(
        v: *FourDim,
        frame_num: usize,
        buffer: *std.array_list.Managed(u8),
    ) !void {

        //LLM: temp save for debug lines
        var buf: [256]u8 = undefined;
        const output_filepath = try std.fmt.bufPrint(&buf, "/Users/joachimpfefferkorn/repos/neurovolume/output/tmp_{d}.vdb", .{frame_num});
        //TODO: save logic based off versioning bool etc
        //in save config (to build in FourDim init)
        _ = v;

        const file = try std.fs.cwd().createFile(
            output_filepath,
            .{},
        );

        try file.writeAll(buffer.items);

        defer file.close();
    }

    //extracts a 3D slice of a 4D ndarray to a VDB
    pub fn extractFrame(
        self: *FourDim,
        allocator: std.mem.Allocator,
        frame_num: usize,
        vdb: *vdb543.VDB,
    ) !void {
        if (frame_num >= self.dims[3]) return AccessError.IndexOutOBounds;
        //Assuming that there aren't headers or things in ndarrays
        //  (I should read the docs I guess)
        const start = frame_num * self.frame_size;
        const end = ((frame_num + 1) * self.frame_size);

        var i: usize = 0;
        var cart = [_]u32{ 0, 0, 0 };
        while (true) {
            try vdb543.setVoxel(
                vdb,
                .{
                    cart[self.cartesian_order[0]],
                    cart[self.cartesian_order[1]],
                    cart[self.cartesian_order[2]],
                },
                self.normalizer.apply(self.data[start..end][i]),
                allocator,
            );

            i += 1;
            if (!util.incrementCartesian(
                u32,
                3,
                &cart,
                .{ self.dims[0], self.dims[1], self.dims[2] },
            )) break;
        }
    }
    pub fn save(
        self: *FourDim,
        interpolation: InterpolationMode,
    ) !void {
        var interpolator = Interpolator{
            .vol = self,
            .mode = interpolation,
        };
        //TODO: save config to somewhere other than the hard coded temp dir
        //see FourDim.saveFrame
        try interpolator.write();
    }
};

const InterpolationError = error{ModeDoesNotExist};

pub const InterpolationMode = enum(c_int) {
    direct = 0,
};

pub const Interpolator = struct {
    vol: *FourDim,
    mode: InterpolationMode,

    pub fn write(self: *Interpolator) !void {
        //HACK: I don't love this pattern, I feel like there is a more elegant way
        //to chose a function below without having to write it out in two places
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const gpa_alloc = gpa.allocator();
        defer _ = gpa.deinit();
        var arena = std.heap.ArenaAllocator.init(gpa_alloc);
        defer arena.deinit();

        switch (self.mode) {
            .direct => try direct(&arena, self.vol),
            // else => {
            //     std.debug.print("Interpolation mode {any} does not exist", .{self.mode});
            //     return InterpolationError.ModeDoesNotExist;
            // },
        }
    }

    // No interpolation
    // Frames from source are written directly
    // to the VDB sequene
    fn direct(
        arena: *std.heap.ArenaAllocator,
        vol: *FourDim,
    ) !void {
        for (0..vol.dims[3]) |n| {
            defer _ = arena.reset(.retain_capacity); //LLM: free per-frame, keep buffer capacity
            var vdb = try vdb543.VDB.build(arena.allocator());
            var buffer = std.array_list.Managed(u8).init(arena.allocator());
            // var buffer = std.ArrayList(u8).init(arena.allocator());
            switch (vol.source_format) {
                .ndarray => try vol.extractFrame(
                    arena.allocator(),
                    n,
                    &vdb,
                ),
                else => return DataFormatError.NotSupportedYet,
            }

            try vdb543.writeVDB(
                &buffer,
                &vdb,
                vol.affine_transform,
            );
            try vol.saveFrame(n, &buffer);
        }
    }
};
