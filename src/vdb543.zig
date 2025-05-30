//Minimal 543 vdb writer based off the JengaFX repo
const std = @import("std");

//IO helper functions
fn writePointer(buffer: *std.ArrayList(u8), pointer: *const u8, len: usize) !void {
    try buffer.appendSlice(pointer[0..len]);
}
fn writeSlice(comptime T: type, buffer: *std.ArrayList(u8), slice: []const T) !void {
    const byte_data = std.mem.sliceAsBytes(slice); //@as([*]const u8, @ptrCast(slice.ptr))[0 .. slice.len * @sizeOf(T)];
    try buffer.appendSlice(byte_data);
}
fn writeU8(buffer: *std.ArrayList(u8), value: u8) !void {
    try buffer.append(value);
}
//NOTE:
//Check endianness for these
//These could probably be dryed with comptimes
fn writeU16(buffer: *std.ArrayList(u8), value: u16) !void {
    try buffer.appendSlice(std.mem.asBytes(&value));
    // try writePointer(buffer, &value, @sizeOf(value));
}
fn writeU32(buffer: *std.ArrayList(u8), value: u32) !void {
    //NOTE: Need to change this to a const u32 somehow (but efficiently!)

    try buffer.appendSlice(std.mem.asBytes(&value));
    // try writePointer(buffer, &v, @sizeOf(value));
}
fn writeU64(buffer: *std.ArrayList(u8), value: u64) !void {
    // try writePointer(buffer, &value, @sizeOf(value));
    try buffer.appendSlice(std.mem.asBytes(&value));
}
fn writeU128(buffer: *std.ArrayList(u8), value: u128) !void {
    // try writePointer(buffer, &value, @sizeOf(value));
    try buffer.appendSlice(std.mem.asBytes(&value));
}
//NOTE: another good argument for comptiming these: this vdb data value should be arbitrary:
fn writeF64(buffer: *std.ArrayList(u8), value: f64) !void {
    // try writePointer(buffer, &value, @sizeOf(value));
    try buffer.appendSlice(std.mem.asBytes(&value));
}
fn castInt32ToU32(value: i32) u32 {
    const result: u32 = @bitCast(value);
    return result;
}
fn writeVec3i(buffer: *std.ArrayList(u8), value: [3]i32) !void {
    try writeU32(buffer, castInt32ToU32(value[0]));
    try writeU32(buffer, castInt32ToU32(value[1]));
    try writeU32(buffer, castInt32ToU32(value[2]));
}

fn writeString(buffer: *std.ArrayList(u8), string: []const u8) !void {
    for (string) |character| {
        try buffer.append(character);
    }
}
fn writeName(buffer: *std.ArrayList(u8), name: []const u8) !void {
    try writeU32(buffer, @intCast(name.len));
    try writeString(buffer, name);
}
fn writeMetaString(buffer: *std.ArrayList(u8), name: []const u8, string: []const u8) !void {
    writeName(buffer, name);
    writeName(buffer, "string");
    writeName(buffer, string);
}
fn writeMetaBool(buffer: *std.ArrayList(u8), name: []const u8, value: bool) !void {
    try writeName(buffer, name);
    try writeName(buffer, "bool");
    try writeU32(buffer, 1); //bool is stored in one whole byte
    try writeU8(buffer, if (value) 1 else 0);
}
fn writeMetaVector(buffer: *std.ArrayList(u8), name: []const u8, value: [3]i32) !void {
    try writeName(buffer, name);
    try writeName(buffer, "vec3i");
    try writeU32(buffer, 3 * @sizeOf(i32));
    try writeVec3i(buffer, value);
}
//VDB nodes
//WARNING: these are VERY BROKEN ZIG CODE. This will not work! Check field_test.zig for an example of how to add allocators and write this properly!
const VDB = struct {
    five_node: Node5,
    //NOTE:  to make this arbitrarily large:
    //You'll need an autohashmap to *Node5s and some mask that encompasses all the node5 (how many?)
    // init: VDB = .{ .five_node = Node5.init };
    pub const init: VDB = .{ .five_node = Node5.init };
    pub fn deinit(self: *VDB, allocator: std.mem.Allocator) void {
        self.five_node.deinit(allocator);
        self.* = undefined;
    }
};
const Node5 = struct {
    mask: [512]u64, //NOTE: maybe thees should be called "masks" plural?
    four_nodes: std.AutoHashMapUnmanaged(u32, *Node4),
    pub const init: Node5 = .{ .mask = @splat(0), .four_nodes = .empty };
    pub fn deinit(self: *Node5, allocator: std.mem.Allocator) void {
        for (self.four_nodes.values()) |node| {
            node.deinit(allocator);
        }
        self.four_nodes.deinit(allocator);
        self.* = undefined;
    }
};
const Node4 = struct {
    mask: [64]u64,
    three_nodes: std.AutoHashMapUnmanaged(u32, *Node3),
    pub const init: Node4 = .{ .mask = @splat(0), .three_nodes = .empty };
};
const Node3 = struct {
    mask: [8]u64,
    data: [512]f16, //this can be any value but we're using f16. Probably should match source!
    pub const init: Node3 = .{ .mask = @splat(0), .data = @splat(0) };
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
    //NOTE: the >>0 is just pedagogical, it doesn't do anything
    const index_3d: [3]u32 = .{ relative_position[0] >> 0, relative_position[1] >> 0, relative_position[2] >> 0 };
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

fn writeNode5Header(buffer: *std.ArrayList(u8), node: *Node5) !void {
    //origin of 5-node:
    try writeVec3i(buffer, .{ 0, 0, 0 });
    //child masks:
    for (node.mask) |child_mask| {
        try writeU64(buffer, child_mask);
    }
    //Presently we don't have any values masks, so just zeroing those out
    for (node.mask) |_| {
        try writeU64(buffer, 0);
    }
    //Write uncompressed (signified by 6) node values
    try writeU8(buffer, 6);
    var i: usize = 0;
    while (i <= 32768) : (i += 1) {
        try writeU16(buffer, 0);
    }
}
fn writeNode4Header(buffer: *std.ArrayList(u8), node: *Node4) !void {
    //Child masks
    for (node.mask) |child_mask| {
        try writeU64(buffer, child_mask);
    }
    //No value masks atm
    for (node.mask) |_| {
        try writeU64(buffer, 0);
    }
    try writeU8(buffer, 6);
    var i: usize = 0;
    while (i <= 4096) : (i += 1) {
        try writeU16(buffer, 0);
    }
}

const TreeError = error{
    FourNodeNotFound,
    ThreeNodeNotFound,
};

fn writeTree(buffer: *std.ArrayList(u8), vdb: *VDB) !void {
    try writeU32(buffer, 1); //Number of value buffers per leaf node (only change for multi-core implementations)
    try writeU32(buffer, 0); //Root node background value
    try writeU32(buffer, 0); //number of tiles
    try writeU32(buffer, 1); //number of 5 nodes

    const node_5 = &vdb.five_node;

    try writeNode5Header(buffer, &node_5);
    //Write masks (I think)
    var bit_index: u32 = 0;
    for (node_5.mask, 0..) |five_mask, five_mask_idx| {
        //Use Kerningham's algorithm to count only the "active" binary spaces in the mask:
        while (five_mask != 0) : (five_mask &= five_mask - 1) {
            bit_index = @as(five_mask_idx, u32) * 64 + @as(@ctz(five_mask), u32); //64 being the depth of the u64 datatype used in the mask
            //NOTE: I don't feel like I have fully internalized the bit_index math

            //TODO: error handling if four node not found
            const node_4 = node_5.four_nodes.get(bit_index);
            writeNode4Header(buffer, &node_4);
            //Iterate 3-nodes
            for (node_4.mask, 0..) |four_mask, four_mask_idx| {
                while (four_mask != 0) : (four_mask &= four_mask - 1) {
                    bit_index = @as(four_mask_idx, u32) * 64 + @as(@ctz(four_mask), u32);
                    const node_3 = node_4.three_nodes.get(bit_index);
                    for (node_3.mask) |three_mask| {
                        try writeU64(buffer, three_mask);
                    }
                }
            }
        }
    }
    //Now we write the actual data (I think)
    for (node_5.mask, 0..) |five_mask, five_mask_idx| {
        while (five_mask != 0) : (five_mask &= five_mask - 1) {
            bit_index = @as(five_mask_idx, u32) * 64 + @as(@ctz(five_mask), u32);
            //NOTE: I feel like there is potential to DRY with some comptimes
            const node_4 = node_5.four_nodes.get(bit_index);
            for (node_4.mask, 0..) |four_mask, four_mask_idx| {
                while (four_mask != 0) : (four_mask &= four_mask_idx - 1) {
                    bit_index = @as(four_mask_idx, u32) * 64 + @as(@ctz(four_mask), u32);
                    const node_3 = node_4.three_nodes.get(bit_index);
                    for (node_3.mask) |three_mask| {
                        writeU64(buffer, three_mask);
                        writeSlice(f16, buffer, node_3.data); //NOTE: probably borked!
                    }
                }
            }
        }
    }
}

fn writeMetadata(buffer: *std.ArrayList(u8)) void {
    // lots of hard coded things that will by dynamic if we expand this!
    writeU32(buffer, 4); //write number of entries
    writeMetaString(buffer, "class", "unknown");
    writeMetaString(buffer, "file_compression", "none");
    writeMetaBool(buffer, "is_saved_as_half_float", true);
    writeMetaString(buffer, "name", "density");
}

fn writeTransform(buffer: *std.ArrayList(u8), affine: [4][4]f64) void {
    writeName(buffer, "AffineMap");

    writeF64(buffer, affine[0][0]);
    writeF64(buffer, affine[1][0]);
    writeF64(buffer, affine[2][0]);
    writeF64(buffer, 0);

    writeF64(buffer, affine[0][1]);
    writeF64(buffer, affine[1][1]);
    writeF64(buffer, affine[2][1]);
    writeF64(buffer, 0);

    writeF64(buffer, affine[0][2]);
    writeF64(buffer, affine[1][2]);
    writeF64(buffer, affine[2][2]);
    writeF64(buffer, 0);

    writeF64(buffer, affine[0][3]);
    writeF64(buffer, affine[1][3]);
    writeF64(buffer, affine[2][3]);
    writeF64(buffer, 0);
}

fn writeGrid(buffer: *std.ArrayList(u8), vdb: *VDB, affine: [4][4]f64) void {
    //grid name (should be dynamic when doing multiple grids)
    writeName(buffer, "density");

    //grid type
    //  (thiswill probably always be 543 but who knows! precision should match source eventually
    writeName(buffer, "Tree_float_5_4_3_HalfFloat");

    //Indicate no instance parent
    writeU32(buffer, 0);

    //Grid descriptor stream position
    //WARNING: I am shaky on what this is, the first line is a direct chatGPT translation of the odin code (bad form on my part)
    writeU64(buffer, @as(u64, buffer.items.len) + @sizeOf(u64) * 3);

    writeU64(buffer, 0);
    writeU64(buffer, 0);

    //no compression
    writeU32(buffer, 0);

    writeMetadata(buffer);
    writeTransform(buffer, affine);
    writeTree(buffer, vdb);
}

fn writeVDB(buffer: *std.ArrayList(u8), vdb: *VDB, affine: [4][4]f64) !void {
    //Magic Number
    try writeSlice(u8, buffer, &.{ 0x20, 0x42, 0x44, 0x56, 0x0, 0x0, 0x0, 0x0 });

    //File Version
    try writeU32(buffer, 224);

    //Library version (pretend OpenVDB 8.1)
    try writeU32(buffer, 8);
    try writeU32(buffer, 1);

    //no grid offsets
    try writeU8(buffer, 0);

    //Temporary UUID
    //TODO: generate one
    try writeString(buffer, "2d46f03e-b0e9-48f1-8311-07f573dbcae2");

    //No Metadata for now
    try writeU32(buffer, 0);

    //One Grid
    try writeU32(buffer, 1);

    try writeGrid(buffer, vdb, affine);
}

//GPT copypasta:
const R: u32 = 128;
const D: u32 = R * 2;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var b = std.ArrayList(u8).init(allocator);
    defer b.deinit();

    var vdb = VDB.init; // assumes you have init()
    defer vdb.deinit(); // assumes you have deinit()

    const Rf: f32 = @floatFromInt(R);
    const R2: f32 = Rf * Rf;

    for (0..D) |z| {
        for (0..D) |y| {
            for (0..D) |x| {
                const p = toF32(.{ x, y, z });
                const diff = subVec(p, .{ Rf, Rf, Rf });
                if (lengthSquared(diff) < R2) {
                    setVoxel(&vdb, .{ @intCast(x), @intCast(y), @intCast(z) }, 1.0);
                }
            }
        }
    }

    const Identity4x4: [4][4]f64 = .{
        .{ 1.0, 0.0, 0.0, 0.0 },
        .{ 0.0, 1.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 1.0, 0.0 },
        .{ 0.0, 0.0, 0.0, 1.0 },
    };
    try writeVDB(&b, &vdb, Identity4x4); // assumes compatible signature

    const file = try std.fs.cwd().createFile("test.vdb", .{});
    defer file.close();
    try file.writeAll(b.items);
}

// Utility functions

fn toF32(v: [3]usize) [3]f32 {
    return .{
        @floatFromInt(v[0]),
        @floatFromInt(v[1]),
        @floatFromInt(v[2]),
    };
}

fn subVec(a: [3]f32, b: [3]f32) [3]f32 {
    return .{
        a[0] - b[0],
        a[1] - b[1],
        a[2] - b[2],
    };
}

fn lengthSquared(v: [3]f32) f32 {
    return v[0] * v[0] + v[1] * v[1] + v[2] * v[2];
}
