const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
pub fn PathExists(string: []const u8) bool {
    _ = std.fs.cwd().openFile(string, .{}) catch {
        return false;
    };
    return true;
}
//TODO:
// - [ ] Build if not there
// - [ ] Enumerate if there

//Checks if a string could be a directory
fn validDir(string: []const u8) bool { //NOTE: .openDir might have this baked in already  ¯\_ (ツ)_/¯
    const split = std.mem.splitBackwardsScalar(u8, string, "/");
    //check if valid basename

    const basename = split.first();
    if (std.mem.count(u8, basename, ".") > 0) {
        return false;
    }
    if (PathExists(split.rest)) {
        return true;
    } else {
        return false;
    }
}

const DirectoryBuildError = error{
    InvalidDirectory,
};
//Builds a directory if one is not present at that filepath
pub fn BuildDirIfAbsent(string: []const u8) void {
    if (PathExists(string)) {
        return;
    }
    if (validDir(string)) {
        const dir = try std.fs.cwd().openDir(string, .{});
        defer dir.close();
    } else {
        return DirectoryBuildError.InvalidDirectory;
    }
}

//not moving these into testing as I might build a small utility library with them
test "path exists" {
    const no_path = PathExists("hamspamland/88cacca9-c0f0-4ed2-b378-04a5ade73b8a/ham");
    assert(no_path == false);
    const yes_path = PathExists("./util.zig");
    assert(yes_path == true);

    print("Non existent path evaluates as {}\nExistent path evaluates as {}\n", .{ no_path, yes_path });

    const local_path = PathExists("/Users/joachimpfefferkorn/repos/neurovolume/src");
    //WARNING: this only works on my machine
    assert(local_path == true);
    print("Local path's existence is {}\n", .{local_path});
}
test "valid dir" {
    //WARNING: paths only work on my machine
    const bad_path = "/ham/spam/land";
    const bad_name = "/Users/joachimpfefferkorn/ham.spam";
    const good_path = "./test_dir";
    BuildDirIfAbsent(bad_path);
    BuildDirIfAbsent(bad_name);
    BuildDirIfAbsent(good_path);
}
