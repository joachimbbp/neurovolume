//NOTE:
//I am presently only using f32 (and should implement that in the vdb as well)
//This is because the slslope and slinter are f32, which thus sets the data
//to sort of always be this. I am curious what the larger datatypes
//typically do (do the super big ones just not use slope and inter?)

//TODO:
// [ ] Add multiple grids
// [ ] Add tiles
// [ ] Arbitrary input data
// [ ]  setVoxels one 3-node at a time to reduce syscalls
// [ ] Improve error handling
//SUBMODULE:
// This is an external UUID writing dependency (written by me, Joachim)
// If you don't want to deal with imports feel free to hard code a
// UUID down under the comment "write UUID"
// Note it is a git submodule!
const zools = @import("./zools/src/root.zig");

const ArrayList = std.array_list.Managed;

const std = @import("std");
const print = std.debug.print;

//SECTION: IO helper functions
fn writePointer(buffer: *ArrayList(u8), pointer: *const u8, len: usize) !void {
    try buffer.appendSlice(pointer[0..len]);
}
fn writeSlice(comptime T: type, buffer: *ArrayList(u8), slice: []const T) !void {
    const byte_data = std.mem.sliceAsBytes(slice);
    try buffer.appendSlice(byte_data);
}
fn writeU8(buffer: *ArrayList(u8), value: u8) !void {
    try buffer.append(value);
}
fn writeScalar(comptime T: type, buffer: *ArrayList(u8), value: T) !void {
    try buffer.appendSlice(std.mem.asBytes(&value));
}

fn castInt32ToU32(value: i32) u32 {
    const result: u32 = @bitCast(value);
    return result;
}
fn writeVec3i(buffer: *ArrayList(u8), value: [3]i32) !void {
    try writeScalar(u32, buffer, castInt32ToU32(value[0]));
    try writeScalar(u32, buffer, castInt32ToU32(value[1]));
    try writeScalar(u32, buffer, castInt32ToU32(value[2]));
}

fn writeString(buffer: *ArrayList(u8), string: []const u8) !void {
    for (string) |character| {
        try buffer.append(character);
    }
}

fn writeName(buffer: *ArrayList(u8), name: []const u8) !void {
    try writeScalar(u32, buffer, @intCast(name.len));
    try writeString(buffer, name);
}
fn writeMetaString(buffer: *ArrayList(u8), name: []const u8, string: []const u8) !void {
    try writeName(buffer, name);
    try writeName(buffer, "string");
    try writeName(buffer, string);
}
fn writeMetaBool(buffer: *ArrayList(u8), name: []const u8, value: bool) !void {
    try writeName(buffer, name);
    try writeName(buffer, "bool");
    try writeScalar(u32, buffer, 1); //bool is stored in one whole byte
    try writeU8(buffer, if (value) 1 else 0);
}
fn writeMetaVector(buffer: *ArrayList(u8), name: []const u8, value: [3]i32) !void {
    try writeName(buffer, name);
    try writeName(buffer, "vec3i");
    try writeScalar(u32, buffer, 3 * @sizeOf(i32));
    try writeVec3i(buffer, value);
}
//SECTION: VDB nodes
pub const VDB = struct {
    five_node: *Node5,
    //NOTE:  to make this arbitrarily large:
    //You'll need an autohashmap to *Node5s and some mask that encompasses all the node5 (how many?)
    pub fn build(allocator: std.mem.Allocator) !VDB {
        const five_node = try Node5.build(allocator);
        return VDB{ .five_node = five_node };
    }
};
const Node5 = struct {
    mask: [512]u64, // maybe thees should be called "masks" plural?
    four_nodes: std.AutoHashMap(u32, *Node4),
    fn build(allocator: std.mem.Allocator) !*Node5 {
        const four_nodes = std.AutoHashMap(u32, *Node4).init(allocator);
        const node5 = try allocator.create(Node5);
        node5.* = Node5{ .mask = @splat(0), .four_nodes = four_nodes };
        return node5;
    }
};
const Node4 = struct {
    mask: [64]u64,
    three_nodes: std.AutoHashMap(u32, *Node3),
    fn build(allocator: std.mem.Allocator) !*Node4 {
        const three_nodes = std.AutoHashMap(u32, *Node3).init(allocator);

        const node4 = try allocator.create(Node4);
        node4.* = Node4{ .mask = @splat(0), .three_nodes = three_nodes };

        return node4;
    }
};

const Node3 = struct {
    mask: [8]u64,
    data: [512]f32, //can technically be any value!
    fn build(allocator: std.mem.Allocator) !*Node3 {
        const node3 = try allocator.create(Node3);
        node3.* = Node3{ .mask = @splat(0), .data = @splat(@as(f32, 0)) };
        return node3;
    }
};

//SECTION: Bit index functions:
// Generalized Function to pack the whole thing down into xxxyyyzzz:
// From the original: bit_index = z + y * dim + x * dim^2
// bit_index = z | (y << dim) | (x << (dim << 1))
// Note the pedagogical code (4096-1, etc). This is a holdover
// from the jengaFX repo. I'm keeping it around for clarity
// as I don't believe there is a runtime performance hit.
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
    return index_3d[2] | (index_3d[1] << 4) | (index_3d[0] << 8);
}
fn getBitIndex0(position: [3]u32) u32 {
    const relative_position: [3]u32 = .{ position[0] & (8 - 1), position[1] & (8 - 1), position[2] & (8 - 1) };
    const index_3d: [3]u32 = .{ relative_position[0] >> 0, relative_position[1] >> 0, relative_position[2] >> 0 };
    return index_3d[2] | (index_3d[1] << 3) | (index_3d[0] << 6);
}

pub fn setVoxel(vdb: *VDB, position: [3]u32, value: f32, allocator: std.mem.Allocator) !void {
    var node_5: *Node5 = vdb.five_node;

    const bit_index_4 = getBitIndex4(position);
    const bit_index_3 = getBitIndex3(position);
    const bit_index_0 = getBitIndex0(position);

    var node_4: *Node4 = undefined;
    const node_4_or_null = node_5.four_nodes.get(bit_index_4);
    if (node_4_or_null == null) {
        node_4 = try Node4.build(allocator);
        try node_5.four_nodes.put(bit_index_4, node_4);
    } else {
        node_4 = node_4_or_null.?;
    }

    var node_3: *Node3 = undefined;
    const node_3_or_null = node_4.three_nodes.get(bit_index_3);
    if (node_3_or_null == null) {
        node_3 = try Node3.build(allocator);
        try node_4.three_nodes.put(bit_index_3, node_3);
    } else {
        node_3 = node_3_or_null.?;
    }

    const one: u64 = 1;
    node_5.mask[bit_index_4 >> 6] |= one << @intCast(bit_index_4 & (64 - 1));
    node_4.mask[bit_index_3 >> 6] |= one << @intCast(bit_index_3 & (64 - 1));
    node_3.mask[bit_index_0 >> 6] |= one << @intCast(bit_index_0 & (64 - 1));

    node_3.data[bit_index_0] = value;
    // print("value at setVoxel: {d}\n", .{value});
    // print("bit index 4: {d}\n", .{bit_index_4});
    // print("bit index 3: {d}\n", .{bit_index_3});
    // print("bit index 0: {d}\n", .{bit_index_0});
}

fn writeNode5Header(buffer: *ArrayList(u8), node: *Node5) !void {
    //origin of 5-node:
    try writeVec3i(buffer, .{ 0, 0, 0 });
    //child masks:
    for (node.mask) |child_mask| {
        try writeScalar(u64, buffer, child_mask);
    }
    //Presently we don't have any values masks, so just zeroing those out
    for (node.mask) |_| {
        try writeScalar(u64, buffer, 0);
    }
    //Write uncompressed (signified by 6) node values
    try writeU8(buffer, 6);
    var i: usize = 0;
    while (i < 32768) : (i += 1) {
        try writeScalar(f32, buffer, 0);
    }
}
fn writeNode4Header(buffer: *ArrayList(u8), node: *Node4) !void {
    //Child masks
    for (node.mask) |child_mask| {
        try writeScalar(u64, buffer, child_mask);
    }
    //No value masks atm
    for (node.mask) |_| {
        try writeScalar(u64, buffer, 0);
    }

    try writeU8(buffer, 6);
    var i: usize = 0;
    while (i < 4096) : (i += 1) {
        try writeScalar(f32, buffer, 0);
    }
}

const TreeError = error{
    FourNodeNotFound,
    ThreeNodeNotFound,
};

fn writeTree(buffer: *ArrayList(u8), vdb: *VDB) !void {
    try writeScalar(u32, buffer, 1); //Number of value buffers per leaf node (only change for multi-core implementations)
    try writeScalar(u32, buffer, 0); //Root node background value
    try writeScalar(u32, buffer, 0); //number of tiles
    try writeScalar(u32, buffer, 1); //number of 5 nodes

    const node_5 = vdb.five_node;

    try writeNode5Header(buffer, node_5);

    //CREATE TOPOLOGY:
    for (node_5.mask[0..], 0..) |five_mask_og_t, five_mask_idx_t| {
        var five_mask_t = five_mask_og_t;
        while (five_mask_t != 0) : (five_mask_t &= five_mask_t - 1) {
            const bit_index_4n = @as(u32, @intCast(five_mask_idx_t)) * @as(u32, @intCast(64)) + @as(u32, @ctz(five_mask_t));
            const node_4 = node_5.four_nodes.get(bit_index_4n).?;

            try writeNode4Header(buffer, node_4);

            //Iterate 3-nodes
            for (node_4.mask[0..], 0..) |four_mask_og_t, four_mask_idx_t| {
                var four_mask_t = four_mask_og_t;
                while (four_mask_t != 0) : (four_mask_t &= four_mask_t - 1) {
                    const bit_index_3n_t = @as(u32, @intCast(four_mask_idx_t)) * @as(u32, @intCast(64)) + @as(u32, @ctz(four_mask_t));
                    const node_3_t = node_4.three_nodes.get(bit_index_3n_t).?;
                    for (node_3_t.mask) |three_mask| {
                        try writeScalar(u64, buffer, three_mask);
                    }
                }
            }
        }
    }

    //WRITE DATA
    for (node_5.mask[0..], 0..) |five_mask_og_d, five_mask_idx_d| {
        var five_mask_d = five_mask_og_d;
        while (five_mask_d != 0) : (five_mask_d &= five_mask_d - 1) {
            const bit_index_4_d = @as(u32, @intCast(five_mask_idx_d)) * @as(u32, @intCast(64)) + @as(u32, @intCast(@ctz(five_mask_d)));
            const node_4_t = node_5.four_nodes.get(bit_index_4_d).?;

            for (node_4_t.mask[0..], 0..) |four_mask_og_d, four_mask_idx_d| {
                var four_mask_d = four_mask_og_d;
                while (four_mask_d != 0) : (four_mask_d &= four_mask_d - 1) {
                    const bit_index_3_d = @as(u32, @intCast(four_mask_idx_d)) * 64 + @as(u32, @intCast(@ctz(four_mask_d)));
                    const node_3_d = node_4_t.three_nodes.get(bit_index_3_d).?;
                    for (node_3_d.mask) |three_mask| {
                        try writeScalar(u64, buffer, three_mask); //we must re-write the masks for some reason
                    }
                    try writeU8(buffer, 6); //6 means no compression
                    try writeSlice(f32, buffer, &node_3_d.data);
                }
            }
        }
    }
    //    print("end of tree writing function\n", .{});
}

fn writeMetadata(buffer: *ArrayList(u8)) !void {
    // lots of hard coded things that will by dynamic if we expand this!
    try writeScalar(u32, buffer, 4); //write number of entries
    try writeMetaString(buffer, "class", "unknown");
    try writeMetaString(buffer, "file_compression", "none");
    try writeMetaBool(buffer, "is_saved_as_half_float", false);
    try writeMetaString(buffer, "name", "density");
}

fn writeTransform(buffer: *ArrayList(u8), affine: [4][4]f64) !void {
    try writeName(buffer, "AffineMap");

    try writeScalar(f64, buffer, affine[0][0]);
    try writeScalar(f64, buffer, affine[1][0]);
    try writeScalar(f64, buffer, affine[2][0]);
    try writeScalar(f64, buffer, 0);

    try writeScalar(f64, buffer, affine[0][1]);
    try writeScalar(f64, buffer, affine[1][1]);
    try writeScalar(f64, buffer, affine[2][1]);
    try writeScalar(f64, buffer, 0);

    try writeScalar(f64, buffer, affine[0][2]);
    try writeScalar(f64, buffer, affine[1][2]);
    try writeScalar(f64, buffer, affine[2][2]);
    try writeScalar(f64, buffer, 0);

    try writeScalar(f64, buffer, affine[0][3]);
    try writeScalar(f64, buffer, affine[1][3]);
    try writeScalar(f64, buffer, affine[2][3]);
    try writeScalar(f64, buffer, 1);
}

fn writeGrid(buffer: *ArrayList(u8), vdb: *VDB, affine: [4][4]f64) !void {
    //grid name (should be dynamic when doing multiple grids)
    try writeName(buffer, "density");

    //grid type
    //  (thiswill probably always be 543 but who knows! precision should match source eventually
    try writeName(buffer, "Tree_float_5_4_3");

    //Indicate no instance parent
    try writeScalar(u32, buffer, 0);

    //Grid descriptor stream position
    try writeScalar(u64, buffer, @as(u64, @intCast(buffer.items.len)) + @sizeOf(u64) * 3);
    try writeScalar(u64, buffer, 0);
    try writeScalar(u64, buffer, 0);

    //no compression
    try writeScalar(u32, buffer, 0);

    try writeMetadata(buffer);
    try writeTransform(buffer, affine);
    try writeTree(buffer, vdb);
}

pub fn writeVDB(buffer: *ArrayList(u8), vdb: *VDB, affine: [4][4]f64) !void {
    //Magic Number (needed it spells out BDV)
    try writeSlice(u8, buffer, &.{ 0x20, 0x42, 0x44, 0x56, 0x0, 0x0, 0x0, 0x0 });

    //File Version
    try writeScalar(u32, buffer, 224);

    //Library version (pretend OpenVDB 8.1)
    try writeScalar(u32, buffer, 8);
    try writeScalar(u32, buffer, 1);

    //no grid offsets
    try writeU8(buffer, 0);

    //write UUID
    const uuid = zools.uuid.v4(); //Feel free to replace with your own
    try writeString(buffer, uuid[0..]);

    //No Metadata for now
    try writeScalar(u32, buffer, 0);

    //One Grid
    try writeScalar(u32, buffer, 1);

    try writeGrid(buffer, vdb, affine);
}

//SECTION: Utility functions
pub fn toF32(v: [3]usize) [3]f32 {
    return .{
        @floatFromInt(v[0]),
        @floatFromInt(v[1]),
        @floatFromInt(v[2]),
    };
}

pub fn subVec(a: [3]f32, b: [3]f32) [3]f32 {
    return .{
        a[0] - b[0],
        a[1] - b[1],
        a[2] - b[2],
    };
}

pub fn lengthSquared(v: [3]f32) f32 {
    return v[0] * v[0] + v[1] * v[1] + v[2] * v[2];
}
