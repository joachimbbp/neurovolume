const std = @import("std");
const nifti1 = @import("nifti1.zig");
const util = @import("util.zig");
const cErr = util.cErr;
const vdb543 = @import("vdb543.zig");

pub const Volume = extern struct {
    //Loaded from source
    name: [*:0]const u8,

    frames: [*]const []f32,
    transform: *const [4][4]f64,

    source_fps: f32,
    playback_fps: f32,
    speed: f32, //0.0 for still, 1.0 for normal, 2.0 for 2X speed

    dims: *const [3]usize,
    c_o: *const [3]usize, // Cartesian coordinaes Order
    // I believe:
    // 2 1 0 for ndarray
    // 0 1 2 for nifti1

    effects: []const *const fn (v: *Volume) [][]f32, //effects are applied on the data in memory
    interpolation: *const fn (v: *Volume) [][]f32, //interpolation happens while creating the VDB

    pub fn render_effects(self: *Volume) void {
        for (self.effects) |effect| {
            self.frames = effect(self) catch |e| {
                cErr(e);
            };
        }
    }

    pub fn toVDB(
        self: *Volume,
        alloc: std.mem.Allocator,
        save_path: [*:0]const u8,
        overwrite: bool, //if false, will version file
    ) usize {
        var vdb = vdb543.VDB.build(alloc) catch |e| {
            return cErr(e);
        };
        for (self.frames) |frame| {
            var cart = [_]u32{ 0, 0, 0 };
            var i: usize = 0;
            while (util.incrementCartesian(3, &cart, .dims)) {
                i += 1;
                try vdb543.setVoxel(
                    &vdb,
                    .{ cart[self.c_o[0]], cart[self.c_o[1]], cart[self.c_o[2]] },
                    frame[i],
                    alloc,
                );
            }

            var buffer = std.array_list.Managed(u8).init(alloc);
            defer buffer.deinit();

            if (overwrite) {
                const file = std.fs.cwd().createFile(save_path, .{}) catch |e| {
                    cErr(e);
                };
                try file.writeAll(buffer.items);
                defer file.close();
            } else {
                std.debug.print("file versioning not implemented yet!\n file not saved\n", .{});
            }
        }
    }
};
