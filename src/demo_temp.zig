const std = @import("std");

extern fn deps_test() void;

pub fn main() void {
    deps_test();
}
