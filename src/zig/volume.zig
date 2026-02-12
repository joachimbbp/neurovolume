const std = @import("std");
const nifti1 = @import("nifti1.zig");
const util = @import("util.zig");
const vdb543 = @import("vdb543.zig");
const interpolation = @import("interpolation.zig");

pub const Volume = struct {
    base_allocator: std.mem.Allocator,
    name: []const u8,
    data: [*]f32,
    transform: [4][4]f64,
    source_fps: f32,
    playback_fps: f32,
    speed: f32, //0.0 for still, 1.0 for normal, 2.0 for 2X speed

    dims: [3]usize,
    cartesian_order: [3]usize, // Cartesian coordinaes Order
    // I believe: 2 1 0 for ndarray, 0 1 2 for nifti1

    //DEPRECATED: trivial now????
    // pub fn init(
    //     base_allocator: std.mem.Allocator,
    //     name: []const u8,
    //     data: []f32, //raw voxel data
    //     dims: [4]usize,
    //     cartesian_order: [3]usize, // Cartesian coordinaes Order
    //     transform: [4][4]f64,
    //     source_fps: f32,
    //     playback_fps: f32,
    //     speed: f32, //0.0 for still, 1.0 for normal, 2.0 for 2X speed
    // ) !Volume {
    //     return .{
    //         .base
    //         .name = name,
    //         .frame_allocator = frame_allocator,
    //         .transform = transform,
    //         .source_fps = source_fps,
    //         .playback_fps = playback_fps,
    //         .speed = speed,
    //         .dims = dims,
    //         .cartesian_order = cartesian_order,
    //     };
    // }
    //
    pub fn deinit(self: *Volume) void {
        self.frame_allocator.deinit();
    }

    pub fn toVDB(
        self: *Volume,
        alloc: std.mem.Allocator,
        save_path: [*:0]const u8,
        overwrite: bool, //if false, will version file
        voxel_setter: *const fn (self) anyerror!void,
    ) !void {
        var vdb = try vdb543.VDB.build(alloc);
        try voxel_setter(self, &vdb);
        //BOOKMARK:
        //this is at a good place for  calling separate functions
        //based on what interpolation you want
        //up next:
        //- [ ] finish function with save
        //- [ ] test this functionality
        //- [ ] add new interpolation modes

        //         var buffer = std.array_list.Managed(u8).init(alloc);
        //         defer buffer.deinit();
        //
        //         if (overwrite) {
        //             const file = try std.fs.cwd().createFile(save_path, .{});
        //
        //             try file.writeAll(buffer.items);
        //             defer file.close();
        //         } else {
        //             std.debug.print("file versioning not implemented yet!\n file not saved\n", .{});
        //         }
        //     }
        // }
    }

    //_: Voxel Setters/Interpolation

    //No interpolation
    pub fn direct(self: *Volume, vdb: *vdb543.VDB) !void {
        for (self.data) |v| {
            var cart = [_]u32{ 0, 0, 0 };
            var i: usize = 0;
            while (util.incrementcartesian(3, &cart, .dims)) {
                i += 1;
                try vdb543.setvoxel(
                    vdb,
                    .{
                        cart[self.cartesian_order[0]],
                        cart[self.cartesian_order[1]],
                        cart[self.cartesian_order[2]],
                    },
                    v[i],
                    self.alloc,
                );
            }
        }
    }
};

//Interpolation methods:
