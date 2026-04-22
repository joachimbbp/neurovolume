//TODO:
// - [ ] DRY 3D and 4D volumes as much as possible wihtout getting over zealous
// - [ ] crossfade interpolation
// - [ ] move VDB saving functionality to the vdb module (and alert Robbie)
const std = @import("std");
const ndarray = @import("ndarray.zig");
const util = @import("util.zig");
const vdb543 = @import("vdb543.zig");

const numpy = @import("numpy.zig");

const DataFormatError = error{ NotSupportedYet, UnsupportedUsage };
const AccessError = error{IndexOutOBounds};

pub const SourceFormat = enum(c_int) {
    ndarray = 0,
    nifti1 = 1,
};

const ndarray_fyi = "FYI: To ensure compliance, use the prep_ndarray function in the python library. Ndarrays are assumed to be normalized f32s in C order";

pub const SaveConfiguration = struct {
    basename: []const u8,
    folder: []const u8,
    overwrite: bool, // if false, saves version number
};

pub const Grid = struct {
    alloc: std.mem.Allocator,
    name: []const u8,
    cartesian_order: [3]usize,
    source_format: SourceFormat,
    affine_transform: [4][4]f64,
    normalize: bool,
    dims: [3]usize,
    prune: ?f32,
    vdb: vdb543.VDB,
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
    ) Grid {
        return .{
            .alloc = alloc,
            .name = name,
            .cartesian_order = cartesian_order,
            .source_format = source_format,
            .affine_transform = affine_transform,
            .normalize = normalize,
            .dims = dims,
            .prune = prune,
            .vdb = .init(0),
            .grid = null,
        };
    }

    //populates the vdb543.Grid with VDB data
    pub fn populate(
        g: *Grid,
        data: []const f32,
    ) !Grid {
        //setup based on data source type (just numpy for now)
        var normalizer: util.Normalizer = undefined;
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
                normalizer = util.Normalizer.init(false, 0.0, 1.0);
            },
            //extraction logic only works for slices derrived from ndarrays at the moment
            else => return DataFormatError.NotSupportedYet,
        }
        // var vdb: vdb543.VDB = .init(0);

        //populate the data
        //formerly in fn extract()
        var i: usize = 0;
        var cart = [_]i32{ 0, 0, 0 };
        while (true) {
            try g.vdb.putVoxel(
                g.alloc,
                .from(.{ cart[g.cartesian_order[0]], cart[g.cartesian_order[1]], cart[g.cartesian_order[2]] }),
                normalizer.apply(data[i]),
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

        //LLM suggestion to heap allocate
        //(probably a more memory efficient way to do this tbh!)
        const grid = try g.alloc.create(vdb543.Grid);
        grid.* = .{.init{ &g.vdb, g.name, g.affine_transform, .empty }};

        //TODO: see if you can add prune level to metadata
        try grid.addMetadata(g.alloc, g.name);
        g.vdb = grid;
    }
    pub fn deinit(g: *Grid) void {
        g.vdb.deinit(g.alloc);
    }
};
pub const ThreeDim = struct {
    name: []const u8,
    grids: []const *vdb543.Grid,
    save_config: SaveConfiguration,

    pub fn save(
        v: *ThreeDim,
    ) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const gpa_alloc = gpa.allocator();
        defer _ = gpa.deinit();

        var w: std.Io.Writer.Allocating = .init(gpa_alloc);
        try w.writer.print("{s}/{s}.vdb", .{ v.save_config.folder, v.save_config.basename });

        var arena = std.heap.ArenaAllocator.init(gpa_alloc);
        defer arena.deinit();

        var buffer: [2048]u8 = undefined;
        const file = try std.fs.cwd().createFile(w.written(), .{});
        defer file.close();
        w.deinit();
        var writer = file.writer(&buffer);

        var vdb: vdb543.VDB = .init(0);
        defer vdb.deinit(arena.allocator());
        switch (v.source_format) {
            .ndarray => try v.extractVol(
                arena.allocator(),
                &vdb,
            ),
            else => return DataFormatError.NotSupportedYet,
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

test "volume grid tests" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();

    //WARN: run from root!
    const sphere =
    Grid.init(arena.allocator, "sphere", )
    //BOOKMARK: WAIT! the ndarray needs to be prepped! as in prep_ndarray
    // probably just get an llm to quickly write the zig version?

    numpy.loadAsF32Slice(arena.allocator(), "sphere.npy").?;
    _ = sphere; // autofix
    
    
    // const sphere_grid = buildGrid(, name: []const u8, data: []const f32, cartesian_order: [3]usize, source_format: SourceFormat, affine_transform: [4][4]f64, normalize: bool, dims: [3]usize, prune: ?f32)
    const cube = numpy.loadAsF32Slice(arena.allocator(), "cube.npy").?;
    _ = cube; // autofix


}
