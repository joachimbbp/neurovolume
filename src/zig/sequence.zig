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
const ChannelError = error{MismatchedChannelLengths};

pub const Channel = struct {
    alloc: std.mem.Allocator,
    name: []const u8,
    data: []const f32,
    //grids stuff
    frame_cartesian_order: [3]usize, //WARN: 4D specific prep_ndarray probably needed!
    source_format: SourceFormat,
    affine_transform: [4][4]f64, //might change for 4D? Not sure
    // normalize: bool, //unused rn
    dims: [4]usize, //T X Y Z
    prune: ?f32,
    num_frames: usize,
    frame_size: usize,

    pub fn init(
        alloc: std.mem.Allocator,
        name: []const u8,
        data: []const f32,
        //grids stuff
        frame_cartesian_order: [3]usize, //WARN: 4D specific prep_ndarray probably needed!
        source_format: SourceFormat,
        affine_transform: [4][4]f64, //might change for 4D? Not sure
        // normalize: bool, //unused rn
        dims: [4]usize, //T X Y Z
        prune: ?f32,
        num_frames: usize,
    ) !Channel {
        return .{
            .alloc = alloc,
            .name = name,
            .data = data,
            .frame_cartesian_order = frame_cartesian_order,
            .source_format = source_format,
            .affine_transform = affine_transform,
            .dims = dims,
            .prune = prune,
            .num_frames = num_frames,
            .frame_size = dims[1] * dims[2] * dims[3],
        };
    }

    //no deinit as nothing is heap allocated

    //extracts a 3D slice of a 4D ndarray to a grid
    pub fn extractFrame(
        c: *Channel,
        frame_num: usize,
    ) !vdb543.Grid {
        if (frame_num >= c.dims[0]) return AccessError.IndexOutOBounds;
        var frame_grid = try volume.Grid.init(
            c.alloc,
            c.name,
            [3]usize{ 0, 1, 2 },
            .ndarray,
            c.affine_transform,
            false,
            c.dims[1..4].*, //omits [0] (time dimension)
            c.prune,
        );

        const start_end: [2]usize = .{ frame_num * c.frame_size, ((frame_num + 1) * c.frame_size) };
        try frame_grid.populate(c.data, start_end);
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
                return ChannelError.MismatchedChannelLengths;
            }
        }

        // save each frame once
        for (0..seq_len) |frame| {
            try s.saveFrame(frame, arena.allocator());
        }
    }
};

test "sequence tests" {
    // BOOKMARK:
    //TODO: download and align another BOLD image
    // (probably best to test that on the python layer if you have to pad it)
    // /Users/joachimpfefferkorn/repos/neurovolume/tests/data/sub-02_task-emotionalfaces_run-1_bold.nii

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
        cube_arr.shape[0..4].*,
        prune,
        cube_arr.shape[0],
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
        pyramid_arr.shape[0..4].*,
        prune,
        pyramid_arr.shape[0],
    );

    std.debug.print("initializing sequence...", .{});
    var shapes_seq: Sequence = .{
        .channels = &[_]*Channel{ &cube_channel, &pyramid_channel },
        .save_config = .{
            .basename = "shapes_multigrid",
            .folder = "./tests/data/vdb_out/shapes_seq/",
            .overwrite = true,
        },
    };
    std.debug.print("saving sequence...", .{});
    try shapes_seq.save();
}
