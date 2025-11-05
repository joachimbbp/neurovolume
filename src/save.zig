const std = @import("std");
const Io = std.Io;
const util = @import("util.zig");
const ArrayList = std.array_list.Managed;

// Builds a directory if one is not present at that filepath
// Returns true for absent paths
pub fn dirIfAbsent(path_string: []const u8) !bool {
    if (!try std.fs.accessAbsolute(path_string, .{})) {
        try std.fs.cwd().makeDir(path_string);
        return true;
    }
    return false;
}
pub fn versionName(path_string: []const u8, arena: std.mem.Allocator) !ArrayList(u8) {
    const version_delimiter = "_";
    var output = ArrayList(u8).init(arena);

    if (@TypeOf(std.fs.accessAbsolute(path_string, .{})) != void) {
        for (path_string) |c| {
            try output.append(c);
        }
        return output;
    }
    const dir = std.fs.path.dirname(path_string).?;
    const file = std.fs.path.basenamePosix(path_string);
    const dot_i = std.mem.lastIndexOfScalar(u8, file, '.'); //ROBOT:
    var base: []const u8 = undefined;
    var ext: []const u8 = undefined;
    if (dot_i == null) {
        //No file extension, probably a directory
        ext = "";
        //thus no "basename" either
        base = "";
    } else {
        base = file[0..dot_i.?];
        ext = file[dot_i.? + 1 ..];
    }

    var version: u32 = 1;
    var prefix: []const u8 = undefined;

    var version_split = std.mem.splitBackwardsSequence(u8, base, version_delimiter);

    const possible_version_number = version_split.first();
    if (util.charIsInt(possible_version_number)) {
        version = try std.fmt.parseInt(u32, possible_version_number, 10) + 1;
        prefix = version_split.rest();
    } else {
        version_split.reset();
        prefix = version_split.rest();
    }

    var result: []const u8 = undefined;

    result = try std.fmt.allocPrint(arena, "{s}/{s}_{d}.{s}", .{
        dir,
        prefix,
        version,
        ext,
    });

    if (try std.fs.accessAbsolute(result, .{})) {
        result = (try versionName(result, arena)).items;
    }

    for (result) |c| {
        try output.append(c);
    }
    arena.free(result);
    return output;
}
pub fn versionFile(
    path_string: []const u8,
    buffer: ArrayList(u8),
    alloc: std.mem.Allocator,
) !ArrayList(u8) {
    const file_name = try versionName(path_string, alloc);
    const file = try std.fs.cwd().createFile(file_name.items, .{});
    try file.writeAll(buffer.items);
    defer file.close();
    return file_name;
}
pub fn folderVersionName(folderpath: []const u8, arena: std.mem.Allocator) !ArrayList(u8) {
    const version_delimiter = "_";
    var output = ArrayList(u8).init(arena);
    if (@TypeOf(std.fs.accessAbsolute(folderpath, .{})) != void) {
        for (folderpath) |c| {
            try output.append(c);
        }
        return output;
    }

    const dir = std.fs.path.dirname(folderpath).?;
    const foldername = std.fs.path.basenamePosix(folderpath);

    var version: u32 = 1;
    var prefix: []const u8 = undefined;
    var version_split = std.mem.splitBackwardsSequence(
        u8,
        foldername,
        version_delimiter,
    );

    const pv_number = version_split.first();
    if (util.charIsInt(pv_number)) {
        version = try std.fmt.parseInt(u32, pv_number, 10) + 1;
        prefix = version_split.rest();
    } else {
        version_split.reset();
        prefix = version_split.rest();
    }
    var result: []const u8 = try std.fmt.allocPrint(arena, "{s}/{s}_{d}", .{
        dir,
        prefix,
        version,
    });
    if (try std.fs.accessAbsolute(result, .{})) {
        result = (try folderVersionName(result, arena)).items;
    }

    for (result) |c| {
        try output.append(c);
    }
    arena.free(result);
    return output;
}
pub fn versionFolder(path_string: []const u8, arena: std.mem.Allocator) !ArrayList(u8) {
    const folder_name = try folderVersionName(path_string, arena);
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
