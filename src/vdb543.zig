//NOTE:
//I am presently only using f32 (and should implement that in the vdb as well)
//This is because the slslope and slinter are f32, which thus sets the data
//to sort of always be this. I am curious what the larger datatypes
//typically do (do the super big ones just not use slope and inter?)

const std = @import("std");
const print = std.debug.print;
//IO helper functions
fn writePointer(buffer: *std.ArrayList(u8), pointer: *const u8, len: usize) void {
    buffer.appendSlice(pointer[0..len]) catch unreachable;
}
fn writeSlice(comptime T: type, buffer: *std.ArrayList(u8), slice: []const T) void {
    const byte_data = std.mem.sliceAsBytes(slice);
    //print("writeSlice byte_data: {x}\n", .{byte_data});
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
    data: [512]f16, //this can be any value but we're using f16. Probably should match source!
    fn build(allocator: std.mem.Allocator) !*Node3 {
        const node3 = try allocator.create(Node3);
        node3.* = Node3{ .mask = @splat(0), .data = @splat(@as(f16, 0)) };
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
    return index_3d[2] | (index_3d[1] << 4) | (index_3d[0] << 8);
}
fn getBitIndex0(position: [3]u32) u32 {
    const relative_position: [3]u32 = .{ position[0] & (8 - 1), position[1] & (8 - 1), position[2] & (8 - 1) };
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
    node_5.mask[bit_index_4 >> 6] |= one << @intCast(bit_index_4 & (64 - 1));
    node_4.mask[bit_index_3 >> 6] |= one << @intCast(bit_index_3 & (64 - 1));
    node_3.mask[bit_index_0 >> 6] |= one << @intCast(bit_index_0 & (64 - 1));

    node_3.data[bit_index_0] = value;
    // print("value at setVoxel: {d}\n", .{value});
    // print("bit index 4: {d}\n", .{bit_index_4});
    // print("bit index 3: {d}\n", .{bit_index_3});
    // print("bit index 0: {d}\n", .{bit_index_0});
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
    while (i < 32768) : (i += 1) {
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
    while (i < 4096) : (i += 1) {
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

    //CREATE TOPOLOGY:
    for (node_5.mask[0..], 0..) |five_mask_og_t, five_mask_idx_t| {
        var five_mask_t = five_mask_og_t;
        while (five_mask_t != 0) : (five_mask_t &= five_mask_t - 1) {
            const bit_index_4n = @as(u32, @intCast(five_mask_idx_t)) * @as(u32, @intCast(64)) + @as(u32, @ctz(five_mask_t));
            const node_4 = node_5.four_nodes.get(bit_index_4n).?;

            writeNode4Header(buffer, node_4);

            //Iterate 3-nodes
            for (node_4.mask[0..], 0..) |four_mask_og_t, four_mask_idx_t| {
                var four_mask_t = four_mask_og_t;
                while (four_mask_t != 0) : (four_mask_t &= four_mask_t - 1) {
                    const bit_index_3n_t = @as(u32, @intCast(four_mask_idx_t)) * @as(u32, @intCast(64)) + @as(u32, @ctz(four_mask_t));
                    const node_3_t = node_4.three_nodes.get(bit_index_3n_t).?;
                    for (node_3_t.mask) |three_mask| {
                        writeU64(buffer, three_mask);
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
                        writeU64(buffer, three_mask); //we must re-write the masks for some reason
                    }
                    writeU8(buffer, 6); //6 means no compression
                    writeSlice(f16, buffer, &node_3_d.data);
                }
            }
        }
    }
    print("end of tree writing function\n", .{});
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
    writeF64(buffer, 1);
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
    writeU64(buffer, @as(u64, @intCast(buffer.items.len)) + @sizeOf(u64) * 3);
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

const R: u32 = 128;
const D: u32 = R * 2;

test "shape" {
    const cube = false;
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
    // print("setting voxels\n", .{});
    for (0..D - 1) |z| {
        for (0..D - 1) |y| {
            for (0..D - 1) |x| {
                const p = toF32(.{ x, y, z });
                const diff = subVec(p, .{ Rf, Rf, Rf });
                if (cube == true) {
                    try setVoxel(&vdb, .{ @intCast(x), @intCast(y), @intCast(z) }, 1.0, allocator);
                }
                if (cube == false) {
                    if (lengthSquared(diff) < R2) {
                        try setVoxel(&vdb, .{ @intCast(x), @intCast(y), @intCast(z) }, 1.0, allocator);
                    }
                }
            }
        }
    }

    //printTree(vdb);
    const Identity4x4: [4][4]f64 = .{
        .{ 1.0, 0.0, 0.0, 0.0 },
        .{ 0.0, 1.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 1.0, 0.0 },
        .{ 0.0, 0.0, 0.0, 1.0 },
    };
    writeVDB(&buffer, &vdb, Identity4x4); // assumes compatible signature
    //printBuffer(&buffer);

    const file0 = try std.fs.cwd().createFile("/Users/joachimpfefferkorn/repos/neurovolume/output/1916_zig.vdb", .{});
    defer file0.close();
    try file0.writeAll(buffer.items);
    if (cube == true) {
        print("\ncubin\n", .{});
    }
}

test "test_patern" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    const allocator = arena.allocator();

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var vdb = try VDB.build(allocator);

    print("setting voxels\n", .{});
    try setVoxel(&vdb, .{ @intCast(0), @intCast(0), @intCast(0) }, 1.0, allocator);
    const Identity4x4: [4][4]f64 = .{
        .{ 1.0, 0.0, 0.0, 0.0 },
        .{ 0.0, 1.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 1.0, 0.0 },
        .{ 0.0, 0.0, 0.0, 1.0 },
    };
    writeVDB(&buffer, &vdb, Identity4x4); // assumes compatible signature
    //printBuffer(&buffer);

    const file0 = try std.fs.cwd().createFile("/Users/joachimpfefferkorn/repos/neurovolume/output/one_voxel_01_zig.vdb", .{});
    defer file0.close();
    try file0.writeAll(buffer.items);
}

const nifti1 = @import("nifti1.zig");
test "nifti" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    const allocator = arena.allocator();

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    const path = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii";
    const img = try nifti1.Image.init(path);
    defer img.deinit();
    (&img).printHeader();
    const dims = img.header.dim;
    print("\nDimensions: {d}\n", .{dims});
    //check to make sure it's a static 3D image:
    if (dims[0] != 3) {
        print("Warning! Not a static 3D file. Has {d} dimensions\n", .{dims[0]});
    }
    var vdb = try VDB.build(allocator);

    print("iterating nifti file\n", .{});
    for (0..@as(usize, @intCast(dims[3]))) |z| {
        for (0..@as(usize, @intCast(dims[2]))) |x| {
            for (0..@as(usize, @intCast(dims[1]))) |y| {
                const val = try img.getAt4D([4]usize{ x, y, z, 0 });
                //needs to be f16
                //TODO: probably you'll want normalization functions here, then plug it into the VDB (or an ACII visualizer, or image generator for debugging)
                //as in: norm_val = normalize(val, minmax)
                //TODO: vdb should accept multiple types
                try setVoxel(&vdb, .{ @intCast(x), @intCast(y), @intCast(z) }, @floatCast(val), allocator);
            }
        }
    }
    const Identity4x4: [4][4]f64 = .{
        .{ 1.0, 0.0, 0.0, 0.0 },
        .{ 0.0, 1.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 1.0, 0.0 },
        .{ 0.0, 0.0, 0.0, 1.0 },
    };
    writeVDB(&buffer, &vdb, Identity4x4); // assumes compatible signature
    //printBuffer(&buffer);

    const file0 = try std.fs.cwd().createFile("/Users/joachimpfefferkorn/repos/neurovolume/output/nifti_zig.vdb", .{});
    defer file0.close();
    try file0.writeAll(buffer.items);
    print("\nnifti file written\n", .{});
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
