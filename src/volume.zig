const std = @import("std");
const nifti1 = @import("nifti1.zig");
const config = @import("config.zig.zon");

//This is a WIP, universal replacement for Nifti1/Image
name: []const u8,
//header: []const u8,
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
) !@This() {
    //WARN: This might be specific to Nifti, so don't be afraid to move this logic into the switch!
    const file = try std.fs.cwd().openFile(filepath, .{});
    const reader = std.fs.File.deprecatedReader(file); //DEPRECATED:
    const hdr_ptr = try alloc.create(Header);
    //BUG: memory is leaked here. Claude thinks we should
    //store this but I'm not sure that's the best idea
    hdr_ptr.* = try reader.readStruct(Header);

    const name = try nameFromPath(filepath, alloc);
    switch (format) {
        Format.NIfTI_1 => {
            const x = @as(u64, @intCast(hdr_ptr.*.dim[1]));
            const y = @as(u64, @intCast(hdr_ptr.*.dim[2]));
            const z = @as(u64, @intCast(hdr_ptr.*.dim[3]));
            return .{
                .name = name,
                .resolution = .{ x, y, z },
            };
        },
    }
}

pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
    //TODO: loop through fields
    alloc.free(self.name);
    //res is comptime so no need to destroy
    //alloc.destroy(self.resolution);
}

//TODO:- deinit
// pub fn deinit(self: *const Image) void {
//       //TODO: everything else
//       //why did robbie put this as destroy for one and free for the other?
//       self.allocator.destroy(self.header);
//       self.allocator.free(self.data);
//   }
//
//TODO: - JSON printing:
//if frames = 1, just print that it's static and omit FPS etc
//TODO: Get at and Min Max
//
//
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
    var vol = try init(
        config.testing.files.nifti1_t1,
        nifti1.Header,
        Format.NIfTI_1,
        gpa_alloc,
    );
    defer vol.deinit(gpa_alloc);
    std.debug.print("n: {s}, r: {any}", .{ vol.name, vol.resolution });
}
