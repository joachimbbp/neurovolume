const vdb543 = @import("vdb543.zig");
const std = @import("std");
const util = @import("util.zig");
const vol = @import("volume.zig");
const constants = @import("constants.zig");

//WARN: untested
pub export fn toFrame(
    data: [*]const f32,
    dims: *const [3]usize,
) usize {
    const cartesian_order = [3]usize{ 2, 1, 0 };
    vol.Frame{
        .data = data,
        .dims = *dims,
        .c_o = &cartesian_order,
    };
}
