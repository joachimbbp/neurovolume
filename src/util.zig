const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
pub fn PathExists(path_string: []const u8) bool {
    _ = std.fs.cwd().openFile(path_string, .{}) catch {
        return false;
    };
    return true;
}
//TODO:
// - [ ] Enumerate if there

//Builds a directory if one is not present at that filepath
pub fn BuildDirIfAbsent(path_string: []const u8) !void {
    if (!PathExists(path_string)) {
        _ = try std.fs.cwd().makeDir(path_string);
    }
}

pub fn SaveVersion(path_string: []const u8) !void {
    var output = path_string;
    var version_exists = true;
    if (PathExists(path_string)) {
        const filename = std.mem.splitBackwardsScalar(u8, path_string, "/").first();
        const version = std.mem.splitBackwardsScalar(u8, filename, "_").first();
        for (version) |c| {
            if ((c < 0) or (c > 9)) {
                version_exists = false;
            }
        }
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
