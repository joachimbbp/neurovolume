const std = @import("std");
const Io = std.Io;

const path = @import("path.zig");
const ArrayList = std.array_list.Managed;

// Builds a directory if one is not present at that filepath
// Returns true for absent paths
pub fn dirIfAbsent(path_string: []const u8) !bool {
    if (!try path.exists(path_string)) {
        try std.fs.cwd().makeDir(path_string);
        return true;
    }
    return false;
}

//TODO: SHould be called fileVersion or
//generally un-curse this whole versioning logic
pub fn version(
    path_string: []const u8,
    buffer: ArrayList(u8),
    alloc: std.mem.Allocator,
) !ArrayList(u8) {
    const file_name = try path.versionName(path_string, alloc);
    const file = try std.fs.cwd().createFile(file_name.items, .{});
    try file.writeAll(buffer.items);
    defer file.close();
    return file_name;
}

pub fn versionFolder(path_string: []const u8, arena: std.mem.Allocator) !ArrayList(u8) {
    const folder_name = try path.folderVersionName(path_string, arena);
    try std.fs.cwd().makeDir(folder_name.items);
    return folder_name;
}


pub fn elementName(
    dir: []const u8,
    basename: []const u8,
    extension: []const u8,
    version_num: usize,
    leading_zeros: u8,
    alloc: std.mem.Allocator,
) ![]const u8 {
    var result: []const u8 = undefined;
    result = try std.fmt.allocPrint(
        alloc,
        "{[dir]s}/{[bn]s}_{[n]d:0>[w]}.{[ext]s}",
        .{ .dir = dir, .bn = basename, .n = version_num, .w = leading_zeros, .ext = extension },
    );
    return result;
}

test "iterate" {
    //NOTE:
    //patern should be:
    //      Test directory exists
    //      write new element name
    //      make sure you're not overwriting an existing file (panic for now)
    //      write sequence element
    std.debug.print("🎥 Testing sequence iteration: \n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    for (0..24) |i| {
        const name = try elementName("ham/spam", "land", "png", i, 3, alloc);
        std.debug.print("   name: {s}\n", .{name});
        alloc.free(name);
    }
}

