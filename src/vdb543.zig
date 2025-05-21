//Minimal 543 vdb writer based off the JengaFX repo
const std = @import("std");

const VDB = extern struct {
    node_5: Node5,
    //to make this n-dimensional:
    //node_5: std.AutoHashMap(Node5)
    //some mask that encompasses all the node5 (how many?)
};
const Node5 = extern struct {
    mask: [512]u64,
    node_4: std.AutoHashMap(u32, *Node4),
};
const Node4 = extern struct {
    mask: [64]u64,
    node_3: std.AutoHashMap(u32, *Node3),
};
const Node3 = extern struct {
    mask: [8]u64,
    data: [512]f16, //this can be any value but we're using f16. Probably should match source!
};

//Bit index functions
//As to not take up tons of memory, these are not packaged with the node structs
//Generalized Function to pack the whole thing down into xxxyyyzzz:
//bit_index = z | (y << dim) | (x << (dim << 1))
fn getBitIndex4(position: [3]u32) u32 {
    //relative_position being the position relative to nearest five node
    //4096 being the total voxel span of a five node
    const relative_position: [3]u32 = .{ position[0] & (4096 - 1), position[1] & (4096 - 1), position[2] & (4096 - 1) };
    const index_3d: [3]u32 = .{
        relative_position[0] >> 7,
        relative_position[1] >> 7,
        relative_position[2] >> 7,
    };
    //Figures out the relative (x,y,z) coordinates of the 4-node relative to the 5-node
    //dimension being 5
    return index_3d[2] | (index_3d[1] << 5) | (index_3d[0] << 10);
}
// fn getBitIndex3(position: [3]u32) u32{
//     const relative_poisition: [3]u32 = .{
//                 position[0] & (4096 - 1),
//                 position[1] & (4096 - 1),
//                 position[2] & (4096 - 1),
//                 };
// // fn setVoxel(vdb: *VDB, position: [3]u32, data: f16) !void{
// //This is very readable but not the most efficient
// //TODO: have this set voxels one 3-node at a time to reduce syscalls
//
// }
