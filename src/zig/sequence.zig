const std = @import("std");
const volume = @import("volume.zig");
const util = @import("util.zig");
const vdb543 = @import("vdb543.zig");

const ndarray_fyi = volume.ndarray_fyi;
const DataFormatError = volume.DataFormatError;
const AccessError = volume.AccessError;
const SourceFormat = volume.SourceFormat;
const SaveConfiguration = volume.SaveConfiguration;

//a sequence of grids
pub const Channel = struct {
    alloc: std.mem.Allocator,
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
            c.dims,
            c.prune,
        );

        const start_end: [2]usize = .{ frame_num * c.frame_size, ((frame_num + 1) * c.frame_size) };
        try frame_grid.populate(c.data, start_end);
    }
};

//Four dimensional volume structure
//nothing is allocated in this struct so no deinit
pub const Sequence = struct {
    channels: []Channel,
    save_config: SaveConfiguration,

    //probably call in with an arena allocator if you are saving lots of frames!
    pub fn save_frame(s: *Sequnce, alloc: std.mem.Allocator, frame_num: usize) !void {
        var w: std.Io.Writer.Allocating = .init(alloc);
        defer w.deinit();
        try w.writer.print("{s}/{s}_{d:0>4}.vdb", .{ s.save_config.folder, s.save_config.basename, frame_num });
        var buffer: [2048]u8 = undefined;
        const file = try std.fs.cwd().createFile(w.written(), .{});
        defer file.close();
        w.deinit();
        var writer = file.writer(&buffer);

        var vdb: vdb543.VDB = .init(0);
        defer vdb.deinit(alloc);

        var grids: [s.channels.len]volume.Grid = .{};
        for (s.channel, 0..) |channel, i| {
            grids[i] = channel.
            // BOOKMARK: basically you have to build the frame, which might necessitate
            // getting a ptr from extractFrame
            // I reccomend continuing to reference volume.zig
        }

        try vdb543.writeVDBFile(
            &writer,
            arena.allocator(),
            v.grids,
            .empty,
        );
        try writer.end();
    }
};
