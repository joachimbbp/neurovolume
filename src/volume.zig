const std = @import("std");

const Volume = @This();
//basename: u8,
testString: []const u8 = "\nvolume string test\n",

pub fn printBasename(v: Volume) void {
    std.debug.print("{s}", .{v.testString});
}
