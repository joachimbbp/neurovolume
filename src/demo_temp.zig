const std = @import("std");

fn hello() void {
    std.debug.print("demo hello!\n", .{});
}

pub fn main() void {
    hello();
}
