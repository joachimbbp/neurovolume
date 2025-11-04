const std = @import("std");

// pub fn load(comptime T: type, filepath: []const u8) !*[]T {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     const gpa_alloc = gpa.allocator();
//     defer _ = gpa.deinit();
//     const file = try std.fs.cwd().openFile(filepath, .{});
//     defer file.close();
//     //    const raw_data = try gpa_alloc.alloc(T,
//     //WIP:
// }
