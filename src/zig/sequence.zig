const std = @import("std");
const volume = @import("volume.zig");
const util = @import("util.zig");
const vdb543 = @import("vdb543.zig");

const ndarray_fyi = volume.ndarray_fyi;
const DataFormatError = volume.DataFormatError;
const AccessError = volume.AccessError;
const SourceFormat = volume.SourceFormat;
const SaveConfiguration = volume.SaveConfiguration;

//TODO: integrate
// this was originally in volume

//basically a Volume with a temporal dimension
pub const Channel = struct {
    // Maybe the chanel takes in the source 4D THEN builds the grids based on interpolation
    // later these are reconciled for trailing frames in the Sequence
    // this necesitates the source to be 4D (so if you want a constant anat scan under your
    // bold or something then you'd have to build that numpy array!)
    name: []const u8,
    data: []const f32,

    //grids stuff
    cartesian_order: [3]usize, //WARN: 4D specific prep_ndarray probably needed!
    source_format: SourceFormat,
    affine_transform: [4][4]f64, //might change for 4D? Not sure
    normalize: bool,
    dims: [3]usize,
    prune: ?f32,
    frames: []volume.Grid,

    //determines how the grids get written:
    source_fps: f32,
    speed: f32, //0.0 for still, 1.0 for normal, 2.0 for 2X speed

    //ALWAYS set from the corresponding sequence:
    playback_fps: f32,
    save_config: SaveConfiguration,

    fn frameFile(
        c: *Channel,
        frame_num: usize,
        allocator: std.mem.Allocator,
    ) !std.fs.File {
        var w: std.Io.Writer.Allocating = .init(allocator);
        defer w.deinit();
        try w.writer.print("{s}/{s}_{d:0>4}.vdb", .{
            c.save_config.folder,
            c.save_config.basename,
            frame_num,
        });
        return try std.fs.cwd().createFile(w.written(), .{});
    }

    //extracts a 3D slice of a 4D ndarray to a grid
    pub fn extractFrame(
        c: *Channel,
        allocator: std.mem.Allocator,
        frame_num: usize,
        vdb: *vdb543.VDB,
    ) !void {
        if (frame_num >= c.dims[0]) return AccessError.IndexOutOBounds;
        const start = frame_num * c.frame_size;
        const end = ((frame_num + 1) * c.frame_size);

        var i: usize = 0;
        var cart = [_]i32{ 0, 0, 0 };
        while (true) {
            try vdb.putVoxel(
                allocator,
                .from(.{
                    cart[c.cartesian_order[0]],
                    cart[c.cartesian_order[1]],
                    cart[c.cartesian_order[2]],
                }),
                c.normalizer.apply(c.data[start..end][i]),
            );

            i += 1;
            if (!util.incrementCartesian(
                i32,
                3,
                &cart,
                .{ c.dims[1], c.dims[2], c.dims[3] },
            )) break;
        }
        if (c.prune) |tol| vdb.prune(tol);
    }
};

// FOUR_DIM:
//Four dimensional volume structure
//nothing is allocated in this struct so no deinit
pub const Sequence = struct {
    playback_fps: f32,
    save_config: SaveConfiguration,

    //TODO: DRY maybe
    pub fn extractInterpolatedFrame(
        self: *Sequence,
        allocator: std.mem.Allocator,
        //HACK: there are better ways to do this I am sure
        // very naive but should work
        a_scalar: f32,
        b_scalar: f32,
        a_frame_num: usize,
        b_frame_num: usize,
        vdb: *vdb543.VDB,
    ) !void {
        if ((a_frame_num >= self.dims[0]) or (b_frame_num >= self.dims[0])) return AccessError.IndexOutOBounds;

        const a_start = a_frame_num * self.frame_size;
        const a_end = ((a_frame_num + 1) * self.frame_size);
        const b_start = b_frame_num * self.frame_size;
        const b_end = ((b_frame_num + 1) * self.frame_size);

        var i: usize = 0;
        var cart = [_]i32{ 0, 0, 0 };
        while (true) {
            //WARN: not sure if normalizer is needed here
            //or if it should be applied when calculating av and bv
            //should be a non issue presently for pre-normalized ndarrays
            const av = self.data[a_start..a_end][i]; //value of a frame voxel at this cart coord
            const bv = self.data[b_start..b_end][i]; //value of b frame voxel at this cart coord
            const voxel_value = (av * a_scalar) + (bv * b_scalar);
            try vdb.putVoxel(
                allocator,
                .from(.{
                    cart[self.cartesian_order[0]],
                    cart[self.cartesian_order[1]],
                    cart[self.cartesian_order[2]],
                }),
                voxel_value,
            );

            i += 1;
            if (!util.incrementCartesian(
                i32,
                3,
                &cart,
                .{ self.dims[1], self.dims[2], self.dims[3] },
            )) break;
        }
        if (self.prune) |tol| vdb.prune(tol);
    }

    pub fn save(
        self: *Sequence,
        interpolation: InterpolationMode,
    ) !void {
        var interpolator = try Interpolator.init(self, interpolation);

        //TODO: save config to somewhere other than the hard coded temp dir
        //see FourDim.saveFrame
        try interpolator.write();
    }
};

const InterpolationError = error{ModeDoesNotExist};

pub const InterpolationMode = enum(c_int) {
    direct = 0,
    crossfade = 1,
};

pub const Interpolator = struct {
    vol: *Sequence,
    mode: InterpolationMode,
    total_frames: usize, //number of frames after interpolation
    hold_durration: usize,

    pub fn init(vol: *Sequence, mode: InterpolationMode) !Interpolator {
        if (mode == .direct) {
            return .{
                .vol = vol,
                .mode = mode,
                .total_frames = vol.dims[0],
                .hold_durration = 1,
            };
        } else {
            //LLM: calculated, it was late, don't judge me
            const total_frames: usize = @intFromFloat(@as(f32, @floatFromInt(vol.dims[0])) / vol.source_fps / vol.speed * vol.playback_fps);
            return .{
                .vol = vol,
                .mode = mode,
                .total_frames = total_frames,
                .hold_durration = total_frames / vol.dims[0], //WARN: edge cases abound for non-int results!
            };
        }
    }

    pub fn write(self: *Interpolator) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const gpa_alloc = gpa.allocator();
        defer _ = gpa.deinit();
        var arena = std.heap.ArenaAllocator.init(gpa_alloc);
        defer arena.deinit();

        switch (self.mode) {
            .direct => try self.direct(&arena),
            .crossfade => try self.crossfade(&arena),
        }
    }

    // No interpolation
    // Frames from source are written directly
    // to the VDB sequence
    fn direct(
        self: *Interpolator,
        arena: *std.heap.ArenaAllocator,
    ) !void {
        for (0..self.vol.dims[0]) |n| {
            defer _ = arena.reset(.retain_capacity); //LLM: free per-frame, keep buffer capacity
            var vdb: vdb543.VDB = .init(0);
            defer vdb.deinit(arena.allocator());

            switch (self.vol.source_format) {
                .ndarray => try self.vol.extractFrame(
                    arena.allocator(),
                    n,
                    &vdb,
                ),
                else => return DataFormatError.NotSupportedYet,
            }

            var g: [1]vdb543.Grid = .{.init(&vdb, "density", self.vol.affine_transform, .empty)};
            defer g[0].deinit(arena.allocator());
            try g[0].addDefaultMetadata(arena.allocator());

            const file = try self.vol.frameFile(n, arena.allocator());
            defer file.close();
            var buf: [2048]u8 = undefined;
            var w = file.writer(&buf);
            try vdb543.writeVDBFile(&w, arena.allocator(), &g, .empty);
            try w.end();
        }
    }

    fn crossfade(
        self: *Interpolator,
        arena: *std.heap.ArenaAllocator,
    ) !void {
        //original frames
        for (0..self.vol.dims[0]) |o| {
            //intraframes
            for (0..self.hold_durration) |i| {
                //TODO: dry with other interpolation modes eventually
                defer _ = arena.reset(.retain_capacity); //LLM: free per-frame, keep buffer capacity
                var vdb: vdb543.VDB = .init(0);
                defer vdb.deinit(arena.allocator());

                //NOTE: f32 because that is our current value for
                //the VDB voxels
                //in the future this type might be arbitrary
                const b_scalar: f32 = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(self.hold_durration));
                const a_scalar: f32 = 1.0 - b_scalar;
                //LLM: I originally had this switched!

                switch (self.vol.source_format) {
                    .ndarray => try self.vol.extractInterpolatedFrame(
                        arena.allocator(),
                        a_scalar,
                        b_scalar,
                        o,
                        o + 1,
                        &vdb,
                    ),
                    else => return DataFormatError.NotSupportedYet,
                }
                var g: [1]vdb543.Grid = .{.init(&vdb, "density", self.vol.affine_transform, .empty)};
                defer g[0].deinit(arena.allocator());
                //TODO: see if you can add prune level to metadata
                try g[0].addDefaultMetadata(arena.allocator());

                const frame_num = o * self.hold_durration + i; //LLM: calculated
                const file = try self.vol.frameFile(frame_num, arena.allocator());
                defer file.close();
                var buf: [2048]u8 = undefined;
                var w = file.writer(&buf);
                try vdb543.writeVDBFile(&w, arena.allocator(), &g, .empty);
                try w.end();
            }
        }
    }
};
