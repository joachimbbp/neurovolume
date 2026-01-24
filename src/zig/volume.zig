const std = @import("std");
const nifti1 = @import("nifti1.zig");
const util = @import("util.zig");
const vdb543 = @import("vdb543.zig");

pub const Volume = struct {
    name: []const u8,
    frames: std.ArrayList([]f32),
    frame_allocator: std.heap.ArenaAllocator,
    transform: [4][4]f64,
    source_fps: f32,
    playback_fps: f32,
    speed: f32, //0.0 for still, 1.0 for normal, 2.0 for 2X speed

    dims: [3]usize,
    cartesian_order: [3]usize, // Cartesian coordinaes Order
    // I believe: 2 1 0 for ndarray, 0 1 2 for nifti1

    pub fn init(
        name: []const u8,
        frame_allocator: std.heap.ArenaAllocator,
        frame_list: [*][]f32,
        transform: [4][4]f64,
        source_fps: f32,
        playback_fps: f32,
        speed: f32, //0.0 for still, 1.0 for normal, 2.0 for 2X speed

        dims: [3]usize,
        cartesian_order: [3]usize, // Cartesian coordinaes Order
    ) !Volume {
        var frames = std.ArrayList([]f32).init(frame_allocator);
        for (frame_list) |f| {
            try frames.append(f);
        }
        return .{
            .name = name,
            .frames = frames,
            .frame_allocator = frame_allocator,
            .transform = transform,
            .source_fps = source_fps,
            .playback_fps = playback_fps,
            .speed = speed,
            .dims = dims,
            .cartesian_order = cartesian_order,
        };
    }

    //TODO: deinit
    pub fn toVDB(
        self: *Volume,
        alloc: std.mem.Allocator,
        save_path: [*:0]const u8,
        overwrite: bool, //if false, will version file
    ) !void {
        var vdb = try vdb543.VDB.build(alloc);
        for (self.frames) |frame| {
            var cart = [_]u32{ 0, 0, 0 };
            var i: usize = 0;
            while (util.incrementCartesian(3, &cart, .dims)) {
                i += 1;
                try vdb543.setVoxel(
                    &vdb,
                    .{
                        cart[self.cartesian_order[0]],
                        cart[self.cartesian_order[1]],
                        cart[self.cartesian_order[2]],
                    },
                    frame[i],
                    alloc,
                );
            }

            var buffer = std.array_list.Managed(u8).init(alloc);
            defer buffer.deinit();

            if (overwrite) {
                const file = try std.fs.cwd().createFile(save_path, .{});

                try file.writeAll(buffer.items);
                defer file.close();
            } else {
                std.debug.print("file versioning not implemented yet!\n file not saved\n", .{});
            }
        }
    }
};
