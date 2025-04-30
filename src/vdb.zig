const std = @import("std");

pub const VDB = struct {
    node_5: Node_5,
    pub const Node_5 = struct { mask: [512]u64 };
};

pub fn testSphere(allocator: std.mem.Allocator) !void { //either return an error or nothing
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    // var vdb
}

fn getBitIndex4(q: [3]u32) u32 {
    var p = q;
    p[0] = p[0] & (4096 - 1);
    p[1] = p[1] & (4096 - 1);
    p[2] = p[2] & (4096 - 1);
    const idx3D = [3]u32{ p[0] >> 7, p[1] >> 7, p[2] >> 7 };

    const results = idx3D[2] | (idx3D[1] << 5) | (idx3D[0] << 10);
    std.log.debug(
        "Input: {d}, output: {d}, output binary {b}\n",
        .{ &q, results, results },
    );
    return results;
}
test "index" {
    std.testing.log_level = .debug;
    _ = getBitIndex4(.{ 102983, 102983, 3509 });
    _ = getBitIndex4(.{ 0, 0, 0 });
    _ = getBitIndex4(.{ 1, 1, 1 });
}
