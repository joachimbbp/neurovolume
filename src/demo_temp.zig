const std = @import("std");

extern fn hello() void;
//NOTE: this works because of the setup in the build file
pub fn main() void {
    hello();
}
