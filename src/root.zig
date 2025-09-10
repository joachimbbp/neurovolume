const std = @import("std");
const zools = @import("zools/src/root.zig");
const testing = std.testing;
const debug = @import("debug.zig");

pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub export fn deps_test() void {
    std.debug.print("Linking zools\n", .{});
    zools.debug.helloZools();
}

//NOTE: you seem to need wrappers to expose functions
pub export fn hello_neurovolume() void {
    debug.helloNeurovolume();
}
