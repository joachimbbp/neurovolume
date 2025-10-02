const std = @import("std");
const print = std.debug.print;
const zools = @import("zools");
const t = zools.timer;
const vdb543 = @import("vdb543.zig");
const VDB = vdb543.VDB;
const config = @import("config.zig.zon");

pub const TestPatternError = error{
    NotYetImplemented,
    FileError,
};

//"tmp" for non persistent output
//"persistent" for default test output (as defined in config.zig.zon)
pub fn saveTestPattern(
    comptime save_dir: []const u8,
    comptime basename: []const u8,
    arena_alloc: *std.mem.Allocator,
    buffer: *std.array_list.Managed(u8),
) !void {
    const fmt = "{s}/{s}.vdb";
    //Maybe a switch is better here?
    if (std.mem.eql(u8, save_dir, "tmp") == true) {
        var tmp_dir = std.testing.tmpDir(.{});
        defer tmp_dir.cleanup();
        const tmp_dir_slice = try tmp_dir.dir.realpathAlloc(arena_alloc.*, ".");
        const default_save_path = try std.fmt.allocPrint(
            arena_alloc.*,
            fmt,
            .{ tmp_dir_slice, basename },
        );
        const final_save_location = try zools.save.version(
            default_save_path,
            buffer.*,
            arena_alloc.*,
        );
        print("Test pattern saved to temp location: {s}\n", .{final_save_location.items});
        return;
    } else if (std.mem.eql(u8, save_dir, "persistent")) {
        const default_persistent_dir = try std.fmt.allocPrint(
            arena_alloc.*,
            fmt,
            .{ config.testing.dirs.output, basename },
        );
        const final_save_location = try zools.save.version(
            default_persistent_dir,
            buffer.*,
            arena_alloc.*,
        );
        print("Test pattern saved to persistent location: {s}\n", .{final_save_location.items});
        return;
    } else {
        const save_path = try std.fmt.allocPrint(arena_alloc.*, fmt, .{ save_dir, basename });
        defer arena_alloc.free(save_path);
        //TODO: Finish implementing!
        print("Error: custom save directory not implemented yet. cannot save to:\n{s}", .{save_dir});
        return TestPatternError.NotYetImplemented;
    }
}
