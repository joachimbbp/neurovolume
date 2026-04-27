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
    dims: [3]usize,
    prune: ?f32,
    num_frames: usize,
    frames: []volume.Grid,

    //extracts a 3D slice of a 4D ndarray to a grid
    pub fn extractFrame(
        c: *Channel,
        frame_num: usize,
    ) !void {
        if (frame_num >= c.dims[0]) return AccessError.IndexOutOBounds;
        var frame_grid = try volume.Grid.init(
            c.alloc,
            c.name,
            [3]usize{ 0, 1, 2 },
            .ndarray,
            c.affine_transform,
            false,
            c.dims[1..4].*,
            c.prune,
        );
        errdefer frame_grid.deinit();

        const start_end: [2]usize = .{ frame_num * c.frame_size, ((frame_num + 1) * c.frame_size) };
        try frame_grid.populate(c.data, start_end);
        c.frames[frame_num] = frame_grid;
    }
};

//Four dimensional volume structure
//nothing is allocated in this struct so no deinit
pub const Sequence = struct {
    channels: []Channel,
    save_config: SaveConfiguration,

    //probably call in with an arena allocator if you are saving lots of frames!
    pub fn saveFrame(s: *Sequence, frame_num: usize) !void {
        //this more or less builds a volume with all the grids in the channels
        // at the appropriate frame

        var grids: [s.channels.len]volume.Grid = .{};
        for (s.channel, 0..) |channel, i| {
            grids[i] = channel.frames[frame_num];
        }

        const frame_vol: volume.Vol = .{
            .grids = grids,
            .save_config = s.save_config,
        };
        frame_vol.save(frame_num);
    }

    pub fn saveSequence(s: *Sequence) !void {
        const seq_len = s.channel[0].num_frames;
        for (s.channels) |channel| {
            if (seq_len != channel.num_frames) {
                // pad these on the python level in numpy if need be
                return ChannelError.MismatchedChannelLengths;
            }
            for (0..seq_len) |frame| {
                saveFrame(frame);
            }
        }
    }
};

test "sequence tests" {
    // BOOKMARK:
    //TODO: download and align another BOLD image
    // (probably best to test that on the python layer if you have to pad it)
    // /Users/joachimpfefferkorn/repos/neurovolume/tests/data/sub-02_task-emotionalfaces_run-1_bold.nii

    const numpy = @import("numpy.zig");
    std.debug.print("🏁Grid tests\n", .{});
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

    //CUBE
    const cube_arr = try numpy.loadNpy(arena.allocator(), "rotating_cube.npy");
    std.debug.print("CUBE SHAPE: {any}\n", .{cube_arr.shape});
    const cube_prepped = try numpy.prepNdarray(
        arena.allocator(),
        cube_arr,
        &[_]usize{ 3, 0, 2, 1 }, //IIRC this is correct for sequences?
    );
    var cube_channel: Channel = .{
        .alloc = arena.allocator(),
        .name = "cube",
        .data = cube_prepped,
        .frame_cartesian_order = [3]usize{ 0, 1, 2 },
        .source_format = .ndarray,
        .affine_transform = identity,
        .dims = cube_arr.shape[0..3].*,
        .prune = prune,
        .num_frames = cube_arr[0], //FIX: wait this is not quite right ubt it's late
        //BOOKMARK:
        // TODO: init with .frames most likely?

    };
    _ = cube_channel; // autofix
}
