const std = @import("std");
const util = @import("util.zig");
const vdb543 = @import("vdb543.zig");

pub const DataFormatError = error{ NotSupportedYet, UnsupportedUsage };
pub const AccessError = error{IndexOutOBounds};

pub const SourceFormat = enum(c_int) {
    ndarray = 0,
    nifti1 = 1,
};

pub const ndarray_fyi = "FYI: To ensure compliance, use the prep_ndarray function in the python library. Ndarrays are assumed to be normalized f32s in C order";

pub const SaveConfiguration = struct {
    basename: []const u8,
    folder: []const u8,
    overwrite: bool, // if false, saves version number
};

//FIX: the naming conventions here are not great
// try to rename these structs so we don't have
// multiple things named "grid" across the codebase
pub const Grid = struct {
    alloc: std.mem.Allocator,
    name: []const u8,
    cartesian_order: [3]usize,
    source_format: SourceFormat,
    affine_transform: [4][4]f64,
    normalize: bool,
    dims: [3]usize,
    prune: ?f32,
    vdb: *vdb543.VDB,
    grid: ?vdb543.Grid,
    pub fn init(
        alloc: std.mem.Allocator,
        name: []const u8,
        cartesian_order: [3]usize,
        source_format: SourceFormat,
        affine_transform: [4][4]f64,
        normalize: bool,
        dims: [3]usize,
        prune: ?f32,
    ) !Grid {
        const vdb_ptr = try alloc.create(vdb543.VDB);
        vdb_ptr.* = .init(0);

        return .{
            .alloc = alloc,
            .name = name,
            .cartesian_order = cartesian_order,
            .source_format = source_format,
            .affine_transform = affine_transform,
            .normalize = normalize,
            .dims = dims,
            .prune = prune,
            .vdb = vdb_ptr,
            .grid = null,
        };
    }

    //populates the vdb543.Grid with VDB data
    pub fn populate(
        g: *Grid,
        data: []const f32,
        start_end: ?[2]usize, // for sequences
    ) !void {
        //setup based on data source type (just numpy for now)
        //switch prongs just open for possible future native fileparsing
        switch (g.source_format) {
            .ndarray => {
                if (g.normalize) {
                    std.debug.print(
                        ndarray_fyi,
                        .{},
                    );
                    return DataFormatError.UnsupportedUsage;
                }
            },
            //extraction logic only works for slices derrived from ndarrays at the moment
            else => return DataFormatError.NotSupportedYet,
        }

        //populate the data
        //formerly in fn extract()
        //TODO: re-dry this again!
        var i: usize = 0;
        var cart = [_]i32{ 0, 0, 0 };
        while (true) {
            var value = data[i];
            if (start_end != null) {
                value = data[start_end.?[0]..start_end.?[1]][i];
            }
            try g.vdb.putVoxel(
                g.alloc,
                .from(.{ cart[g.cartesian_order[0]], cart[g.cartesian_order[1]], cart[g.cartesian_order[2]] }),
                value,
            );
            i += 1;
            if (!util.incrementCartesian(
                i32,
                3,
                &cart,
                .{ g.dims[0], g.dims[1], g.dims[2] },
            )) break;
        }

        //when it is pruning, see if all the values are approx the same
        // the tol is the tolerance amount
        // higher means more things are pruned
        //default is quite strict
        if (g.prune) |tol| g.vdb.prune(tol);

        //LLM suggesting a fix to its own code lol:
        var grid = vdb543.Grid.init(
            g.vdb,
            g.name,
            g.affine_transform,
            .empty,
        );
        try grid.addMetadata(g.alloc, g.name);
        g.grid = grid; // store into the optional field that's already on Grid

        // //TODO: see if you can add prune level to metadata
    }

    pub fn deinit(g: *Grid) void {
        g.vdb.deinit(g.alloc);
        g.alloc.destroy(g.vdb);
    }
};
pub const Vol = struct {
    grids: []vdb543.Grid,
    save_config: SaveConfiguration,

    pub fn save(
        v: *Vol,
        frame_num: ?usize,
    ) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const alloc = gpa.allocator();
        defer _ = gpa.deinit();
        var arena = std.heap.ArenaAllocator.init(alloc);
        defer arena.deinit();

        var w: std.Io.Writer.Allocating = .init(alloc);
        defer w.deinit();
        if (frame_num != null) {
            try w.writer.print("{s}/{s}_{d:0>4}.vdb", .{
                v.save_config.folder,
                v.save_config.basename,
                frame_num.?,
            });
        } else {
            try w.writer.print("{s}/{s}.vdb", .{ v.save_config.folder, v.save_config.basename });
        }
        var buffer: [2048]u8 = undefined;
        const file = try std.fs.cwd().createFile(w.written(), .{});
        defer file.close();
        var writer = file.writer(&buffer);

        var vdb: vdb543.VDB = .init(0);
        defer vdb.deinit(arena.allocator());

        try vdb543.writeVDBFile(
            &writer,
            arena.allocator(),
            v.grids,
            .empty,
        );
        try writer.end();
    }
};

test "volume grid tests" {
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

    //WARN: run from root!

    //SPHERE:
    const sphere_arr = try numpy.loadNpy(arena.allocator(), "sphere.npy");
    std.debug.print("SPHERE SHAPE: {any}\n", .{sphere_arr.shape});
    const sphere_prepped = try numpy.prepNdarray(
        arena.allocator(),
        sphere_arr,
        &[_]usize{ 0, 2, 1 },
    );
    var sphere_grid = try Grid.init(
        arena.allocator(),
        "sphere",
        [3]usize{ 0, 1, 2 },
        .ndarray,
        identity,
        false,
        sphere_arr.shape[0..3].*,
        prune,
    );
    try sphere_grid.populate(sphere_prepped, null);

    //CUBE:
    const cube_arr = try numpy.loadNpy(arena.allocator(), "cube.npy");
    std.debug.print("CUBE SHAPE: {any}\n", .{cube_arr.shape});
    const cube_prepped = try numpy.prepNdarray(
        arena.allocator(),
        cube_arr,
        &[_]usize{ 0, 2, 1 },
    );
    var cube_grid = try Grid.init(
        arena.allocator(),
        "cube",
        [3]usize{ 0, 1, 2 },
        .ndarray,
        identity,
        false,
        cube_arr.shape[0..3].*,
        prune,
    );
    try cube_grid.populate(cube_prepped, null);

    //GATHER GRIDS:
    var grids = [_]vdb543.Grid{ sphere_grid.grid.?, cube_grid.grid.? };

    var multi_grid_vol: Vol = .{
        .grids = &grids,
        .save_config = .{
            .basename = try std.fmt.allocPrint(
                arena.allocator(),
                "multi_grid_v2_pruned_{d}",
                .{prune},
            ),
            .folder = "./tests/data/vdb_out",
            .overwrite = true,
        },
    };
    try multi_grid_vol.save(null);
}
