const ndarray = @import("ndarray.zig");
const volume = @import("volume.zig");
const std = @import("std");

//make sure even unused stuff from volume is testsed:
test {
    std.testing.refAllDecls(volume);
}

// WIP: moving threeDim to use grids

//_: ERROR UTILS:
pub fn cErr(e: anyerror) CError {
    const name = @errorName(e);
    return .{
        //TODO: should this be a c_int????
        .code = @intFromError(e),
        .name = name.ptr,
        .len = name.len,
    };
}

pub const CError = extern struct {
    code: usize,
    name: [*]const u8,
    len: usize,
};

// Print "hello neurovolume" to terminal for testing purposes
pub export fn hello() void {
    std.debug.print("hello neurovolume! Sparse time! Multi grids!\n", .{});
}
test "hello" {
    hello();
}
