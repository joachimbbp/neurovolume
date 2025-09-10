const std = @import("std");
const ArrayList = std.array_list.Managed;
const print = std.debug.print;

//prints hello neurovolume to check import
pub fn helloNeurovolume() void {
    print("🧠 Hello Neurovolume! 🧠\n", .{});
}
