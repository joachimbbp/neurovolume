const std = @import("std");
//IO helpers
// fn writePointer(b:  
//tree data structure
fn writePointer(buffer *ArrayList(u8), 
fn writeU32(buffer: *ArrayList(u8), vector: u32) !void{


}
pub const VDB = extern struct {
    node_5: Node5,
    // pub const Node_5 = struct { mask: [512]u64 };
};

pub const Node5 = extern struct {
    mask: [512]u64,
    node_4: std.ArrayListUnmanaged(Node4),
};

pub const Node4 = extern struct {
    mask: [64]u64,
    node_3: std.AutoHashMap(u32, *Node3), 
    pub const init: Node4 = .{
        .mask = .{0} ** 64,
        .node_3 = .empty,
    };
pub const Node3 = extern struct {
    mask: [8]u64,
    data: [512]f16, //as per the original Odin datatype
};

pub fn testSphere(allocator: std.mem.Allocator) :!void { //either return an error or nothing
    std.debug.print("Creating Test VDB Sphere", .{});
    var buffer = std.ArrayList(u8w.init(allocator);
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
// test "index" {
//     std.testing.log_level = .debug;
//     _ = getBitIndex4(.{ 102983, 102983, 3509 });
//     _ = getBitIndex4(.{ 0, 0, 0 });
//     _ = getBitIndex4(.{ 1, 1, 1 });
// };

fn writeTree(buffer: *std.ArrayList(u8), vdb *VDB) !void {
    //I believe *std.Arraylist(u8) is equivalent to *bytes.Buffer
    
    //needs a 1, even the original jenga code doesn't know why
    //writeU32(buffer, 1)
    }
