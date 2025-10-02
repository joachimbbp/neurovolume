const std = @import("std");
const print = std.debug.print;
const zools = @import("zools");
const t = zools.timer;
const vdb543 = @import("vdb543.zig");
const VDB = vdb543.VDB;

pub const TestPatternError = error{
    NotYetImplemented,
    FileError,
};

pub fn saveTestPattern(
    comptime save_dir: []const u8,
    comptime basename: []const u8,
    arena_alloc: *std.mem.Allocator,
    buffer: *std.array_list.Managed(u8),
) !void {
    const fmt = "{s}/{s}.vdb";
    var save_path = try std.fmt.allocPrint(arena_alloc.*, fmt, .{ save_dir, basename });
    defer arena_alloc.free(save_path);
    if (std.mem.eql(u8, save_dir, "tmp") == true) {
        var tmp_dir = std.testing.tmpDir(.{});
        defer tmp_dir.cleanup();
        const tmp_dir_slice = try tmp_dir.dir.realpathAlloc(arena_alloc.*, ".");
        save_path = try std.fmt.allocPrint(arena_alloc.*, fmt, .{ tmp_dir_slice, basename });
        const final_save_location = try zools.save.version(
            save_path,
            buffer.*,
            arena_alloc.*,
        );
        print("Sphere test pattern saved to: {s}\n", .{final_save_location.items});
    } else {
        //TODO: Implement!
        print("Error: custom save directory not implemented yet. 'tmp' is not given string:\n{s}", .{save_dir});
        return TestPatternError.NotYetImplemented;
    }
}
