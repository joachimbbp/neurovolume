const std = @import("std");
const volume = @import("volume.zig");
const util = @import("util.zig");
const vdb543 = @import("vdb543.zig");

const ndarray_fyi = volume.ndarray_fyi;
//TODO: DRY errors into some unified spot
const DataFormatError = volume.DataFormatError;
const AccessError = volume.AccessError;
const SourceFormat = volume.SourceFormat;
const SaveConfiguration = volume.SaveConfiguration;
const ChannelError = error{ MismatchedRuntimes, NonValidDims };
const WIPError = error{NotImplementedYet};

const Interpolation = enum {
    direct, //write the frames directly to disk
    frozen, //just one frame repeated for the duration, assumes 3D input
    fade, //cross fade between frames to stretch to the runtime
};

pub const Channel = struct {
    alloc: std.mem.Allocator,
    name: []const u8,
    data: []const f32,
    //grids stuff
    frame_cartesian_order: [3]usize, //WARN: 4D specific prep_ndarray probably needed!
    source_format: SourceFormat,
    affine_transform: [4][4]f64,
    spatial_dims: [3]usize,
    num_frames: usize, //TODO: rename to num_source_frames or something?
    interpolation: Interpolation,
    prune: ?f32,
    //For some interpolation you'll need:
    source_fps: ?f32,
    playback_fps: ?f32,
    speed: ?f32,
    num_output_frames: usize, //TODO PERHAPS: set this for all num_framse just for clean
    hold_duration: usize,

    pub fn init(
        alloc: std.mem.Allocator,
        name: []const u8,
        data: []const f32,
        //grids stuff
        frame_cartesian_order: [3]usize, //WARN: 4D specific prep_ndarray probably needed?!
        source_format: SourceFormat,
        affine_transform: [4][4]f64,
        //WARN: don't forget to extract 0th dim to num_frames higher up
        dims: [3]usize, // X Y Z
        num_frames: usize,
        //todo: fps speed and interpolation could get bundled!
        interpolation: Interpolation,
        prune: ?f32,
        source_fps: ?f32,
        playback_fps: ?f32,
        speed: ?f32,
    ) !Channel {
        if (interpolation == Interpolation.fade) {
            const nof: usize = @intFromFloat(@as(f32, @floatFromInt(num_frames)) / source_fps.? / speed.? * playback_fps.?);
            return .{
                .alloc = alloc,
                .name = name,
                .data = data,
                .frame_cartesian_order = frame_cartesian_order,
                .source_format = source_format,
                .affine_transform = affine_transform,
                .spatial_dims = dims,
                .num_frames = num_frames,
                .interpolation = interpolation,
                .prune = prune,
                .source_fps = source_fps,
                .playback_fps = playback_fps,
                .speed = speed,
                .num_output_frames = nof,
                .hold_duration = nof / num_frames,
            };
        } else {
            // TEMP: need to expand with additional interpolation techniques
            return .{
                .alloc = alloc,
                .name = name,
                .data = data,
                .frame_cartesian_order = frame_cartesian_order,
                .source_format = source_format,
                .affine_transform = affine_transform,
                .spatial_dims = dims,
                .num_frames = num_frames,
                .interpolation = interpolation,
                .prune = prune,
                .source_fps = source_fps,
                .playback_fps = playback_fps,
                .speed = speed,
                .num_output_frames = num_frames,
                .hold_duration = 1,
            };
        }
    }
    pub fn debug(c: *Channel) void {
        std.debug.print("{s}\n   source_num_frames: {d} \noutput_num_frames: {d}\n   frozen: {}\n", .{ c.name, c.num_frames, c.num_output_frames, c.interpolation });
    }

    pub fn extractFrame(
        c: *Channel,
        frame_num: ?usize, //frame num can be an i frame!
    ) !vdb543.Grid {
        return switch (c.interpolation) {
            .direct => try direct(c, frame_num, false),
            .frozen => try direct(c, null, true),
            .fade => try fade(c, frame_num.?),
        };
    }

    //extraction function
    pub fn direct(
        c: *Channel,
        frame_num: ?usize,
        frozen: bool,
    ) !vdb543.Grid {
        var frame_grid: volume.Grid = undefined;
        if (frozen) {
            //TODO: option to freeze a specific frame from a 4D seq
            frame_grid = try volume.Grid.init(
                c.alloc,
                c.name,
                [3]usize{ 0, 1, 2 },
                .ndarray,
                c.affine_transform,
                false,
                c.spatial_dims,
                c.prune,
            );
            try frame_grid.populate(c.data, null);
        } else {
            frame_grid = try volume.Grid.init(
                c.alloc,
                c.name,
                [3]usize{ 0, 1, 2 },
                .ndarray,
                c.affine_transform,
                false,
                c.spatial_dims,
                c.prune,
            );

            const frame_size = c.spatial_dims[0] * c.spatial_dims[1] * c.spatial_dims[2];
            const start_end: [2]usize = .{ frame_num.? * frame_size, ((frame_num.? + 1) * frame_size) };
            try frame_grid.populate(c.data, start_end);
        }
        return frame_grid.grid.?;
    }

    //extraction function
    pub fn fade(
        c: *Channel,
        output_frame: usize, //can be an i frame!
    ) !vdb543.Grid {
        const a_frame = output_frame / c.hold_duration;
        const sub = output_frame % c.hold_duration;

        if (sub == 0 or a_frame >= c.num_frames - 1) {
            const clamped = @min(a_frame, c.num_frames - 1);
            return try direct(c, clamped, false);
        }

        const b_frame = a_frame + 1;
        const b_scalar: f32 = @as(f32, @floatFromInt(sub)) / @as(f32, @floatFromInt(c.hold_duration));
        const a_scalar: f32 = 1.0 - b_scalar;

        var frame_grid = try volume.Grid.init(
            c.alloc,
            c.name,
            [3]usize{ 0, 1, 2 },
            .ndarray,
            c.affine_transform,
            false,
            c.spatial_dims,
            c.prune,
        );

        const frame_size = c.spatial_dims[0] * c.spatial_dims[1] * c.spatial_dims[2];
        const a_start = a_frame * frame_size;
        const b_start = b_frame * frame_size;

        var v_idx: usize = 0;
        var cart = [_]i32{ 0, 0, 0 };

        while (true) {
            const av = c.data[a_start + v_idx];
            const bv = c.data[b_start + v_idx];
            const voxel_value = (av * a_scalar) + (bv * b_scalar);

            // vdb.putVoxel(frame_grid.g.)
            try frame_grid.vdb.putVoxel(
                frame_grid.alloc,
                .from(.{
                    cart[frame_grid.cartesian_order[0]],
                    cart[frame_grid.cartesian_order[1]],
                    cart[frame_grid.cartesian_order[2]],
                }),
                voxel_value,
            );

            v_idx += 1;
            if (!util.incrementCartesian(
                i32,
                3,
                &cart,
                .{ c.spatial_dims[0], c.spatial_dims[1], c.spatial_dims[2] },
            )) break;
        }

        if (frame_grid.prune) |tol| frame_grid.vdb.prune(tol);
        //officially the most confusing names I've ever written I'm so sorry...
        var vdb_grid = vdb543.Grid.init(
            frame_grid.vdb,
            frame_grid.name,
            frame_grid.affine_transform,
            .empty,
        );
        try vdb_grid.addMetadata(frame_grid.alloc, frame_grid.name);
        frame_grid.grid = vdb_grid;

        return frame_grid.grid.?;
    }
};

//Four dimensional volume structure
//nothing is allocated in this struct so no deinit
pub const Sequence = struct {
    channels: []const *Channel,
    save_config: SaveConfiguration,

    //probably call in with an arena allocator if you are saving lots of frames!
    pub fn saveFrame(s: *Sequence, frame_num: usize, alloc: std.mem.Allocator) !void {
        const grids = try alloc.alloc(vdb543.Grid, s.channels.len);

        //this more or less builds a volume with all the grids in the channels
        // at the appropriate frame

        for (s.channels, 0..) |channel, i| {
            grids[i] = try channel.extractFrame(frame_num);
        }

        var frame_vol: volume.Vol = .{
            .grids = grids,
            .save_config = s.save_config,
        };
        try frame_vol.save(frame_num);
    }

    pub fn save(s: *Sequence) !void {
        std.fs.cwd().access(s.save_config.folder, .{}) catch {
            try std.fs.cwd().makeDir(s.save_config.folder);
        };
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const gpa_alloc = gpa.allocator();
        defer _ = gpa.deinit();

        var arena = std.heap.ArenaAllocator.init(gpa_alloc);
        defer arena.deinit();

        const seq_len = s.channels[0].num_output_frames;
        //validate first...:
        for (s.channels) |channel| {
            if (seq_len != channel.num_output_frames) {
                //TODO: let some grids just go to blank if
                // they are out of range!
                return ChannelError.MismatchedRuntimes;
            }
        }

        // save each frame once
        for (0..seq_len) |frame| {
            try s.saveFrame(frame, arena.allocator());
        }
    }
};

test "sequence tests" {
    const numpy = @import("numpy.zig");
    std.debug.print("📽️ Sequence tests\n", .{});
    const identity = [4][4]f64{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    };
    // const prune: f32 = 0.5;
    // 1.0 removes the entire thing!
    const prune: f32 = 0.999999;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();

    //NOTES:
    // cube seq...CUBE SHAPE: { 48, 128, 128, 128 }
    // 0th is time here!

    //CUBE:
    std.debug.print("cube seq...", .{});
    const cube_arr = try numpy.loadNpy(arena.allocator(), "rotating_cube.npy");
    std.debug.print("CUBE SHAPE: {any}\n", .{cube_arr.shape});
    const cube_prepped = try numpy.prepNdarray(
        arena.allocator(),
        cube_arr,
        &[_]usize{ 0, 1, 2, 3 },
    );
    var cube_channel = try Channel.init(
        arena.allocator(),
        "cube",
        cube_prepped,
        [3]usize{ 0, 1, 2 },
        .ndarray,
        identity,
        cube_arr.shape[1..4].*,
        cube_arr.shape[0],
        Interpolation.direct,
        prune,
        //obvs not really null but we don't need as it's direct interpolation
        null,
        null,
        null,
    );
    cube_channel.debug();
    //PYRAMID:
    std.debug.print("pyramid seq...", .{});
    const pyramid_arr = try numpy.loadNpy(arena.allocator(), "rotating_pyramid.npy");
    std.debug.print("PYRAMID SHAPE: {any}\n", .{pyramid_arr.shape});
    const pyramid_prepped = try numpy.prepNdarray(
        arena.allocator(),
        pyramid_arr,
        &[_]usize{ 0, 1, 2, 3 },
    );
    var pyramid_channel = try Channel.init(
        arena.allocator(),
        "pyramid",
        pyramid_prepped,
        [3]usize{ 0, 1, 2 },
        .ndarray,
        identity,
        // WARN: assumption is time is 4th dim!
        pyramid_arr.shape[1..4].*,
        pyramid_arr.shape[0],
        Interpolation.direct,
        prune,
        //obvs not really null but we don't need as it's direct interpolation
        null,
        null,
        null,
    );
    pyramid_channel.debug();
    //STATIC SPHERE:
    std.debug.print("sphere static seq...", .{});
    const sphere_arr = try numpy.loadNpy(arena.allocator(), "sphere.npy");
    std.debug.print("SPHERE SHAPE: {any}\n", .{sphere_arr.shape});

    const sphere_prepped = try numpy.prepNdarray(
        arena.allocator(),
        sphere_arr,
        &[_]usize{ 0, 1, 2 },
    );

    var sphere_channel = try Channel.init(
        arena.allocator(),
        "sphere",
        sphere_prepped,
        [3]usize{ 0, 1, 2 },
        .ndarray,
        identity,
        sphere_arr.shape[0..3].*, //i guess you need to make this explicit if it's open ended []usize
        cube_arr.shape[0],
        Interpolation.frozen,
        prune,
        null,
        null,
        null,
    );

    sphere_channel.debug();
    // JITTERY CUBE

    std.debug.print("interpolated jittery cube seq...", .{});
    const jcube_arr = try numpy.loadNpy(arena.allocator(), "jittery_cube.npy");
    std.debug.print("JITTERY CUBE SHAPE: {any}\n", .{sphere_arr.shape});

    const jcube_prepped = try numpy.prepNdarray(
        arena.allocator(),
        jcube_arr,
        &[_]usize{ 0, 1, 2, 3 },
    );
    std.debug.print("I htink th is is jcube frame num: {d}", .{jcube_arr.shape[0]});
    var jcube_channel = try Channel.init(
        arena.allocator(),
        "jcube",
        jcube_prepped,
        [3]usize{ 0, 1, 2 },
        .ndarray,
        identity,
        jcube_arr.shape[1..4].*,
        jcube_arr.shape[0],
        Interpolation.fade,
        prune,
        2,
        24,
        1,
    );
    jcube_channel.debug();

    // SHAPES:
    std.debug.print("initializing sequence...", .{});
    var shapes_seq: Sequence = .{
        .channels = &[_]*Channel{
            &cube_channel,
            &pyramid_channel,
            &sphere_channel,
            &jcube_channel,
        },
        .save_config = .{
            .basename = "shapes_multigrid",
            .folder = "./tests/data/vdb_out/shapes_seq/",
            .overwrite = true,
        },
    };
    std.debug.print("saving sequence...", .{});
    try shapes_seq.save();
}
