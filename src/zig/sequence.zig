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

pub const Channel = struct {
    alloc: std.mem.Allocator,
    name: []const u8,
    data: []const f32,
    //grids stuff
    frame_cartesian_order: [3]usize, //WARN: 4D specific prep_ndarray probably needed!
    source_format: SourceFormat,
    affine_transform: [4][4]f64,
    spatial_dims: [3]usize,
    num_frames: usize,
    prune: ?f32,
    frozen: bool,

    //passing in a 3D array will result in a "frozen" array
    // that just repeats the same volume for the duration of num_frames
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
        num_frames: usize, //the 0th dim in the numpy array
        frozen: bool,
        prune: ?f32,
    ) !Channel {
        std.debug.print("{s}\n   num_frames: {d}\n   frozen: {}\n", .{ name, num_frames, frozen });

        return .{
            .alloc = alloc,
            .name = name,
            .data = data,
            .frame_cartesian_order = frame_cartesian_order,
            .source_format = source_format,
            .affine_transform = affine_transform,
            .spatial_dims = dims,
            .prune = prune,
            .num_frames = num_frames,
            .frozen = frozen,
        };
    }

    //no deinit as nothing is heap allocated

    //extracts a 3D slice of a 4D ndarray to a grid
    pub fn extractFrame(
        c: *Channel,
        frame_num: usize,
    ) !vdb543.Grid {
        var frame_grid: volume.Grid = undefined;
        if (c.frozen) {
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
            const start_end: [2]usize = .{ frame_num * frame_size, ((frame_num + 1) * frame_size) };
            try frame_grid.populate(c.data, start_end);
        }
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
            //BOOKMARK:
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

        const seq_len = s.channels[0].num_frames;
        //validate first...:
        for (s.channels) |channel| {
            if (seq_len != channel.num_frames) {
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
        false,
        prune,
    );

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
        false,
        prune,
    );

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
        true,
        prune,
    );

    // SHAPES:

    std.debug.print("initializing sequence...", .{});
    var shapes_seq: Sequence = .{
        .channels = &[_]*Channel{
            &cube_channel,
            &pyramid_channel,
            &sphere_channel,
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
