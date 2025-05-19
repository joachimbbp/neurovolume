const std = @import("std");
pub const Error = std.mem.Allocator.Error || error{AlreadyExists};
fn UInt(comptime bits: u16) type {
    return @Type(.{ .int = .{ .bits = bits, .signedness = .unsigned } });
}
fn maskIndex(comptime bits: u16, index: usize) struct { usize, UInt(bits) } {
    const array_index: usize = index >> bits;
    const bit_index: UInt(bits) = index % (1 << bits);
    return .{ array_index, bit_index };
}

pub const VDB = extern struct {
    node_5: Node5,
    // pub const Node_5 = struct { mask: [512]u64 };
};

pub const Node5 = extern struct {
    mask: [512]u64,
    node_4: std.ArrayListUnmanaged(Node4),
    pub const init: Node5 = .{
        .mask = .{0} ** 512,
        .node_4 = .empty,
    };
    pub fn add(self: *Node5, allocator: std.mem.Allocator, index: u15, node: Node4) Error!void {
        const array_index, const bit_index = maskIndex(6, index);
        if (self.mask[array_index] & (1 << bit_index) == 1) return error.AlreadyExists;
        self.mask[array_index] |= 1 << bit_index;
        var list_index: usize = 0;
        for (self.mask[0..array_index]) |chunk| {
            list_index += @popCount(chunk);
        }
        list_index += @popCount(self.mask[array_index] % (1 << bit_index));
        try self.node_4.insert(allocator, list_index, node);
    }
};

pub const Node4 = extern struct { mask: [64]u64, node_3: std.AutoHashMap(u32, *Node3) };
pub const Node3 = extern struct {
    mask: [8]u64,
    data: [512]f16, //as per the original Odin datatype
};

pub fn testSphere(allocator: std.mem.Allocator) !void { //either return an error or nothing
    std.debug.print("Creating Test VDB Sphere", .{});
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    // var vdb: Node5 = {}

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
