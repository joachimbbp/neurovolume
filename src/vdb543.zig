//Minimal 543 vdb writer based off the JengaFX repo
const std = @import("std");

const VDB = extern struct {
    five_node: *Node5,
    //NOTE:  to make this arbitrarily large:
    //You'll need an autohashmap to *Node5s and some mask that encompasses all the node5 (how many?)
};
const Node5 = extern struct {
    mask: [512]u64,
    four_nodes: std.AutoHashMap(u32, *Node4),
    const init: Node5 = .{
        .mask = .{0} ** 512,
        .four_nodes = .empty,
    };
};
const Node4 = extern struct {
    mask: [64]u64,
    three_nodes: std.AutoHashMap(u32, *Node3),
    const init: Node4 = .{
        .mask = .{0} ** 64,
        .three_nodes = .empty,
    };
};
const Node3 = extern struct {
    mask: [8]u64,
    data: [512]f16, //this can be any value but we're using f16. Probably should match source!
    const init: Node3 = .{
        .mask = .{0} ** 8,
        .data = .empty,
    };
};

//NOTE: Bit index functions:
//Generalized Function to pack the whole thing down into xxxyyyzzz:
//From the original: bit_index = z + y * dim + x * dim^2
//bit_index = z | (y << dim) | (x << (dim << 1))
//TODO:
// - [ ] Dry out pedagogical code (4096-1) etc
// - [ ] make comptime zig
fn getBitIndex4(position: [3]u32) u32 {
    const relative_position: [3]u32 = .{ position[0] & (4096 - 1), position[1] & (4096 - 1), position[2] & (4096 - 1) };
    const index_3d: [3]u32 = .{
        relative_position[0] >> 7,
        relative_position[1] >> 7,
        relative_position[2] >> 7,
    };
    return index_3d[2] | (index_3d[1] << 5) | (index_3d[0] << 10);
}
fn getBitIndex3(position: [3]u32) u32 {
    const relative_position: [3]u32 = .{ position[0] & (128 - 1), position[1] & (128 - 1), position[2] & (128 - 1) };
    const index_3d: [3]u32 = .{
        relative_position[0] >> 3,
        relative_position[1] >> 3,
        relative_position[2] >> 3,
    };
    return index_3d[2] | (index_3d[1] << 3) | (index_3d[0] << 6);
}
fn getBitIndex0(position: [3]u32) u32 {
    const relative_position: [3]u32 = .{ position[0] & (8 - 1), position[1] & (8 - 1), position[2] & (8 - 1) };
    const index_3d: [3]u32 = .{ relative_position[0] >> 0, relative_position[1] >> 0, relative_position[3] >> 0 };
    return index_3d[2] | (index_3d[1] << 3) | (index_3d[0] << 6);
}

//TODO:
//- [ ] have this set voxels one 3-node at a time to reduce syscalls
//- [ ] have the value type mirror the input data type

fn setVoxel(vdb: *VDB, position: [3]u32, value: f16) void {
    const bit_index_4 = getBitIndex4(position);
    const bit_index_3 = getBitIndex3(position);
    const bit_index_0 = getBitIndex0(position);

    const node_5 = &vdb.*.five_node.init;

    var node_4 = node_5.nodes_4[bit_index_4];
    if (node_4 == .empty) {
        node_4 = node_4.init;
        node_5.four_nodes.put(bit_index_4, node_4);
    }
    var node_3 = node_4.nodes_3[bit_index_3];
    if (node_3 == .empty) {
        node_3 = node_3.init;
        node_4.three_nodes.put(bit_index_3, node_3);
    }
    node_5.mask[bit_index_4 >> 6] |= 1 << (bit_index_4 & (64 - 1));
    node_4.mask[bit_index_3 >> 6] |= 1 << (bit_index_3 & (64 - 1));
    node_3.mask[bit_index_0 >> 6] |= 1 << (bit_index_0 & (64 - 1));

    node_3.data[bit_index_0] = value;
}
