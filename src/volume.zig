const std = @import("std");
const nifti1 = @import("nifti1.zig");
const config = @import("config.zig.zon");

//TODO: This will probably need to be an extern struct for the blender plugin!
pub const Data = struct {
    //This is a WIP, universal replacement for Nifti1/Image
    name: []const u8, //WARN: size might have to be known at comptime
    json_hdr: []const u8,
    resolution: [3]u64, //Should be more than enough for most scientific data
    //frames
    //FPS
    //Interpolation type

    pub const Format = enum {
        NIfTI_1,
    };

    pub fn init(
        filepath: []const u8,
        Header: type,
        format: Format,
        alloc: std.mem.Allocator,
    ) !Data {
        //WARN: This might be specific to Nifti, so don't be afraid to move this logic into the switch!
        //Or even into the nifti1 module, tbh! Time will tell.

        //SOURCE: Thank's Robbie for the updated reader code:
        const file = try std.fs.cwd().openFile(filepath, .{});
        var buf: [4096]u8 = undefined;
        var file_reader = file.reader(&buf);
        const reader = &file_reader.interface;
        const hdr_ptr = try reader.takeStructPointer(Header);

        const json_hdr = try nifti1.jsonFromHeader(hdr_ptr.*, alloc);
        const name = try nameFromPath(filepath, alloc);
        switch (format) {
            Format.NIfTI_1 => {
                const x = @as(u64, @intCast(hdr_ptr.*.dim[1]));
                const y = @as(u64, @intCast(hdr_ptr.*.dim[2]));
                const z = @as(u64, @intCast(hdr_ptr.*.dim[3]));
                return .{
                    .name = name,
                    .resolution = .{ x, y, z },
                    .json_hdr = json_hdr.items,
                };
            },
        }
        defer json_hdr.deinit();
    }

    pub fn deinit(self: *Data, alloc: std.mem.Allocator) void {
        alloc.free(self.name);
    }
};

//_: Utils:
fn nameFromPath(filepath: []const u8, alloc: std.mem.Allocator) ![]const u8 {
    const filename = std.fs.path.basename(filepath);
    var iter = std.mem.splitSequence(u8, filename, ".");
    const name = iter.first();
    return try alloc.dupe(u8, name);
}

//_: Testing:
test "volume" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();
    var vol = try Data.init(
        config.testing.files.nifti1_t1,
        nifti1.Header,
        Data.Format.NIfTI_1,
        gpa_alloc,
    );
    defer vol.deinit(gpa_alloc);
    std.debug.print("n: {s}, r: {any}", .{ vol.name, vol.resolution });
}
