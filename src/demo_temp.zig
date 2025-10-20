const std = @import("std");

fn hello() void {
    std.debug.print("demo hello!\n", .{});
}

//NOTE: this works because of the setup in the build file
pub fn main() void {
    hello();
}
