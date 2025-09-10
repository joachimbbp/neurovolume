//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const zools = @import("zools/src/root.zig");
const testing = std.testing;

pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub export fn deps_test() void {
    std.debug.print("Linking zools\n", .{});
    zools.debug.helloZools();
}

//TEST:
//Let's see if this gets us nifti functionality
pub const nifti1 = @import("nifti1.zig");

// test "basic add functionality" {
//     try testing.expect(add(3, 7) == 10);
// }
