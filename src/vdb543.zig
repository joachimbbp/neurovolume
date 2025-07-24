//Minimal 543 vdb writer based off the JengaFX repo
const std = @import("std");

//IO helper functions
fn writePointer(buffer: *std.ArrayList(u8), pointer: *const u8, len: usize) void {
    buffer.appendSlice(pointer[0..len]) catch unreachable;
}
fn writeSlice(comptime T: type, buffer: *std.ArrayList(u8), slice: []const T) void {
    const byte_data = std.mem.sliceAsBytes(slice); //@as([*]const u8, @ptrCast(slice.ptr))[0 .. slice.len * @sizeOf(T)];
    buffer.appendSlice(byte_data) catch unreachable;
}
fn writeU8(buffer: *std.ArrayList(u8), value: u8) void {
    buffer.append(value) catch unreachable;
}
//NOTE:
//Check endianness for these
//These could probably be dryed with comptimes
fn writeU16(buffer: *std.ArrayList(u8), value: u16) void {
    buffer.appendSlice(std.mem.asBytes(&value)) catch unreachable;
    //  writePointer(buffer, &value, @sizeOf(value));
}
fn writeU32(buffer: *std.ArrayList(u8), value: u32) void {
    //NOTE: Need to change this to a const u32 somehow (but efficiently)

    buffer.appendSlice(std.mem.asBytes(&value)) catch unreachable;

    //  writePointer(buffer, &v, @sizeOf(value));
}
fn writeU64(buffer: *std.ArrayList(u8), value: u64) void {
    //  writePointer(buffer, &value, @sizeOf(value));
    buffer.appendSlice(std.mem.asBytes(&value)) catch unreachable;
}
fn writeU128(buffer: *std.ArrayList(u8), value: u128) void {
    //  writePointer(buffer, &value, @sizeOf(value));
    buffer.appendSlice(std.mem.asBytes(&value)) catch unreachable;
}
//NOTE: another good argument for comptiming these: this vdb data value should be arbitrary:
fn writeF64(buffer: *std.ArrayList(u8), value: f64) void {
    //  writePointer(buffer, &value, @sizeOf(value));
    buffer.appendSlice(std.mem.asBytes(&value)) catch unreachable;
}
fn castInt32ToU32(value: i32) u32 {
    const result: u32 = @bitCast(value);
    return result;
}
fn writeVec3i(buffer: *std.ArrayList(u8), value: [3]i32) void {
    writeU32(buffer, castInt32ToU32(value[0]));
    writeU32(buffer, castInt32ToU32(value[1]));
    writeU32(buffer, castInt32ToU32(value[2]));
}

fn writeString(buffer: *std.ArrayList(u8), string: []const u8) void {
    for (string) |character| {
        buffer.append(character) catch unreachable;
    }
}
fn writeName(buffer: *std.ArrayList(u8), name: []const u8) void {
    writeU32(buffer, @intCast(name.len));
    writeString(buffer, name);
}
fn writeMetaString(buffer: *std.ArrayList(u8), name: []const u8, string: []const u8) void {
    writeName(buffer, name);
    writeName(buffer, "string");
    writeName(buffer, string);
}
fn writeMetaBool(buffer: *std.ArrayList(u8), name: []const u8, value: bool) void {
    writeName(buffer, name);
    writeName(buffer, "bool");
    writeU32(buffer, 1); //bool is stored in one whole byte
    writeU8(buffer, if (value) 1 else 0);
}
fn writeMetaVector(buffer: *std.ArrayList(u8), name: []const u8, value: [3]i32) void {
    writeName(buffer, name);
    writeName(buffer, "vec3i");
    writeU32(buffer, 3 * @sizeOf(i32));
    writeVec3i(buffer, value);
}
//VDB nodes
const VDB = struct {
    five_node: *Node5,
    //NOTE:  to make this arbitrarily large:
    //You'll need an autohashmap to *Node5s and some mask that encompasses all the node5 (how many?)
    fn build(allocator: std.mem.Allocator) !VDB {
        const five_node = try Node5.build(allocator);
        return VDB{ .five_node = five_node };
    }
};
const Node5 = struct {
    mask: [512]u64, //NOTE: maybe thees should be called "masks" plural?
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
    data: [512]f16, //this can be any value but we're using f16. Probably should match source!
    fn build(allocator: std.mem.Allocator) !*Node3 {
        const node3 = try allocator.create(Node3);
        node3.* = Node3{ .mask = @splat(0), .data = @splat(@as(f16, std.math.nan(f16))) };
        return node3;
    }
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

fn setVoxel(vdb: *VDB, position: [3]u32, value: f16, allocator: std.mem.Allocator) !void {
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
    node_5.mask[bit_index_4 >> 6] |= one << @intCast(bit_index_4 & 63);
    node_4.mask[bit_index_3 >> 6] |= one << @intCast(bit_index_3 & 63);
    node_3.mask[bit_index_0 >> 6] |= one << @intCast(bit_index_0 & 63);

    node_3.data[bit_index_0] = value;
}

fn writeNode5Header(buffer: *std.ArrayList(u8), node: *Node5) void {
    //origin of 5-node:
    writeVec3i(buffer, .{ 0, 0, 0 });
    //child masks:
    for (node.mask) |child_mask| {
        writeU64(buffer, child_mask);
    }
    //Presently we don't have any values masks, so just zeroing those out
    for (node.mask) |_| {
        writeU64(buffer, 0);
    }
    //Write uncompressed (signified by 6) node values
    writeU8(buffer, 6);
    var i: usize = 0;
    while (i <= 32768) : (i += 1) {
        writeU16(buffer, 0);
    }
}
fn writeNode4Header(buffer: *std.ArrayList(u8), node: *Node4) void {
    //Child masks
    for (node.mask) |child_mask| {
        writeU64(buffer, child_mask);
    }
    //No value masks atm
    for (node.mask) |_| {
        writeU64(buffer, 0);
    }
    writeU8(buffer, 6);
    var i: usize = 0;
    while (i <= 4096) : (i += 1) {
        writeU16(buffer, 0);
    }
}

const TreeError = error{
    FourNodeNotFound,
    ThreeNodeNotFound,
};

fn writeTree(buffer: *std.ArrayList(u8), vdb: *VDB) void {
    writeU32(buffer, 1); //Number of value buffers per leaf node (only change for multi-core implementations)
    writeU32(buffer, 0); //Root node background value
    writeU32(buffer, 0); //number of tiles
    writeU32(buffer, 1); //number of 5 nodes

    const node_5 = vdb.five_node;

    writeNode5Header(buffer, node_5);

    //var bit_index: u32 = 0;
    for (node_5.mask[0..], 0..) |five_mask_og, five_mask_idx| {
        //Use Kerningham's algorithm to count only the "active" binary spaces in the mask:
        var five_mask = five_mask_og;
        while (five_mask != 0) : (five_mask &= five_mask - 1) {
            const bit_index_4n = @as(u32, @intCast(five_mask_idx)) * 64 + @as(u32, @ctz(five_mask));
            const node_4 = node_5.four_nodes.get(bit_index_4n).?;

            std.debug.print("mask found at four node bit index bit index: {}\n", .{bit_index_4n});

            writeNode4Header(buffer, node_4);

            //Iterate 3-nodes
            std.debug.print("iterating 3 nodes\n", .{});
            for (node_4.mask[0..], 0..) |four_mask_og, four_mask_idx| {
                var four_mask = four_mask_og;
                while (four_mask != 0) : (four_mask &= four_mask - 1) {
                    const bit_index_3n = @as(u32, @intCast(four_mask_idx)) * 64 + @as(u32, @ctz(four_mask));
                    const node_3 = node_4.three_nodes.get(bit_index_3n).?;
                    for (node_3.mask) |three_mask| {
                        writeU64(buffer, three_mask);
                    }
                    writeU8(buffer, 6); //no compression
                    writeSlice(f16, buffer, &node_3.data);
                }
            }
        }
    }

    //Now we write the actual data (I think)
    std.debug.print("writing data\n", .{});
    for (node_5.mask[0..], 0..) |five_mask_og, five_mask_idx| {
        // std.debug.print("   at five mask idx {d}\n", .{five_mask_idx});
        // std.debug.print("   five mask og: {d}", .{five_mask_og});
        var five_mask = five_mask_og;
        //std.debug.print("   five mask: {d}", .{five_mask});
        while (five_mask != 0) : (five_mask &= five_mask - 1) {
            const bit_index_w4n = @as(u32, @intCast(five_mask_idx)) * @as(u32, @intCast(64)) + @as(u32, @intCast(@ctz(five_mask)));
            //NOTE: I feel like there is potential to DRY with some comptimes
            const node_4 = node_5.four_nodes.get(bit_index_w4n).?;
            //std.debug.print("node for gotten at bit index: {d}", .{bit_index_w4n});
            for (node_4.mask[0..], 0..) |four_mask_og, four_mask_idx| {
                var four_mask = four_mask_og;
                while (four_mask != 0) : (four_mask &= four_mask - 1) {
                    const bit_index_w3n = @as(u32, @intCast(four_mask_idx)) * 64 + @as(u32, @intCast(@ctz(four_mask)));
                    const node_3 = node_4.three_nodes.get(bit_index_w3n).?;
                    for (node_3.mask) |three_mask| {
                        //std.debug.print("       writing slice at three mask\n", .{});
                        writeU64(buffer, three_mask);
                        writeSlice(f16, buffer, &node_3.data);
                    }
                }
            }
        }
    }
    std.debug.print("end of tree writing function", .{});
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

fn writeVDB(buffer: *std.ArrayList(u8), vdb: *VDB, affine: [4][4]f64) void {
    //Magic Number (needed it spells out BDV)
    writeSlice(u8, buffer, &.{ 0x20, 0x42, 0x44, 0x56, 0x0, 0x0, 0x0, 0x0 });

    //File Version
    writeU32(buffer, 224);

    //Library version (pretend OpenVDB 8.1)
    writeU32(buffer, 8);
    writeU32(buffer, 1);

    //no grid offsets
    writeU8(buffer, 0);

    //Temporary UUID
    //TODO: generate one
    writeString(buffer, "7a0f79c6-c47a-4954-8af8-8a9dcc384448");

    //No Metadata for now
    writeU32(buffer, 0);

    //One Grid
    writeU32(buffer, 1);

    writeGrid(buffer, vdb, affine);
}

fn printVDB(vdb: VDB) void {
    const p = std.debug.print;
    p("vdb type: {s}\n", .{@typeName(@TypeOf(vdb))});
    const num_four_nodes = vdb.five_node.four_nodes.count();

    p("{d} Four nodes in VDB\n", .{num_four_nodes});
    for (0..num_four_nodes) |n| {
        p("\nFour Node {d}\n", .{n});
        const four_node_opt = vdb.five_node.four_nodes.get(@as(u32, @intCast(n)));
        if (four_node_opt != null) {
            const four_node = four_node_opt.?;
            //p("     mask: {any}\n", .{four_node.mask});
            const num_three_nodes = four_node.three_nodes.count();
            p("     Number of three nodes: {d}\n", .{num_three_nodes});
            //TODO: Fix this:
            //            for (0..num_three_nodes) |m| {
            //                p("             Number of leafs: {d}\n", .{four_node.three_nodes.get(@as(u32, @intCast(m))).data});
            //           }

        } else {
            p("     Four node is null\n", .{});
        }
    }
}

//GPT copypasta:
const R: u32 = 128;
const D: u32 = R * 2;

test "sphere" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    const allocator = arena.allocator();

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var vdb = try VDB.build(allocator);

    const Rf: f32 = @floatFromInt(R);
    const R2: f32 = Rf * Rf;
    std.debug.print("setting voxels\n", .{});
    for (0..D) |z| {
        for (0..D) |y| {
            for (0..D) |x| {
                const p = toF32(.{ x, y, z });
                const diff = subVec(p, .{ Rf, Rf, Rf });
                if (lengthSquared(diff) < R2) {
                    //                    std.debug.print("loop is at {}{}{}\n", .{ z, x, y });
                    try setVoxel(&vdb, .{ @intCast(x), @intCast(y), @intCast(z) }, 1.0, allocator);
                }
            }
        }
    }

    //SANITY CHECK:
    printVDB(vdb);
    const Identity4x4: [4][4]f64 = .{
        .{ 1.0, 0.0, 0.0, 0.0 },
        .{ 0.0, 1.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 1.0, 0.0 },
        .{ 0.0, 0.0, 0.0, 1.0 },
    };
    writeVDB(&buffer, &vdb, Identity4x4); // assumes compatible signature

    const file = try std.fs.cwd().createFile("/Users/joachimpfefferkorn/repos/neurovolume/output/test_zig.vdb", .{});
    defer file.close();
    try file.writeAll(buffer.items);
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
