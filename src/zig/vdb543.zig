//TODO:
// [ ] True Sparcity (I believe this includes "tiles")
// [ ] Add multiple grids
// [ ] Arbitrary input data (presently locked at f32)
// [ ] Optimizations (if needed)
//      [ ]  setVoxels one 3-node at a time to reduce syscalls (
// [ ] Improve error handling
//DEPRECATED: remove this abstraction eventually
const ArrayList = std.array_list.Managed;

const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");
const uuidv4 = util.UUIDv4;
const save = @import("save.zig");

const Writer = std.Io.Writer;

//SECTION: VDB nodes

pub const Point = packed struct {
    x: i32,
    y: i32,
    z: i32,

    pub fn from(array: [3]i32) Point {
        return .{ .x = array[0], .y = array[1], .z = array[2] };
    }

    pub fn offsetOf(p: Point, comptime n: u5, comptime m: u5) u32 {
        const o = n - m;
        const x: u32 = @bitCast((p.x & ((1 << n) - 1)) >> m);
        const y: u32 = @bitCast((p.y & ((1 << n) - 1)) >> m);
        const z: u32 = @bitCast((p.z & ((1 << n) - 1)) >> m);
        return (x << (o + o)) + (y << o) + z;
    }

    pub fn maskLower(p: Point, comptime n: u5) Point {
        const mask: i32 = mask: {
            const mask: i32 = ((1 << n) - 1);
            break :mask ~mask;
        };
        return .{
            .x = p.x & mask,
            .y = p.y & mask,
            .z = p.z & mask,
        };
    }

    pub fn format(p: Point, w: *Writer) Writer.Error!void {
        try w.writeInt(i32, p.x, .little);
        try w.writeInt(i32, p.y, .little);
        try w.writeInt(i32, p.z, .little);
    }
};

pub const VDB = VDBType(f32, 5, 4, 3, false);

pub fn InternalNode(comptime V: type, comptime N: u5) type {
    return struct {
        pub const dim = N + N + N;
        pub const size = 1 << dim;
        pub const Data = union {
            value: V,
            child: usize,
        };
        data: [size]Data,
        value_mask: std.bit_set.ArrayBitSet(usize, size),
        child_mask: std.bit_set.ArrayBitSet(usize, size),
        origin: Point,

        const Node = @This();

        pub fn init(origin: Point) Node {
            return .{
                .data = undefined,
                .value_mask = .initEmpty(),
                .child_mask = .initEmpty(),
                .origin = origin,
            };
        }

        pub fn format(self: *const Node, w: *Writer) Writer.Error!void {
            for (&self.child_mask.masks) |mask| try w.writeInt(usize, mask, .little);
            for (&self.value_mask.masks) |mask| try w.writeInt(usize, mask, .little);
            // FIXME: compression?
            try w.writeByte(6);
            var it = self.value_mask.iterator(.{ .direction = .forward, .kind = .set });
            var index: usize = 0;
            while (it.next()) |entry| : (index = entry + 1) {
                _ = try w.splatByte(0, @sizeOf(V) * (entry - index)); // inactive values are zero
                try w.writeAll(std.mem.asBytes(&self.data[entry]));
            }
            _ = try w.splatByte(0, @sizeOf(V) * (size - index));
        }
    };
}

pub fn LeafNode(comptime N: u5, comptime include_inside: bool) type {
    return struct {
        const Self = @This();
        pub const dim = N + N + N;
        pub const size = 1 << dim;
        pub const Flags = packed struct(u64) {
            buf_count: u2 = 1,
            compressed: bool = false,
            quantized: bool = false,
            origin: packed struct {
                x: i20,
                y: i20,
                z: i20,
            },

            pub fn init(p: Point) Flags {
                return .{ .origin = .{
                    .x = @truncate(p.x >> N),
                    .y = @truncate(p.y >> N),
                    .z = @truncate(p.z >> N),
                } };
            }
        };
        data_offset: usize,
        value_mask: std.bit_set.ArrayBitSet(usize, size) = .initEmpty(),
        inside_mask: if (include_inside)
            std.bit_set.ArrayBitSet(usize, size)
        else
            void = if (include_inside) .initEmpty() else {},
        flags: Flags,

        pub fn format(self: *const @This(), w: *Writer) Writer.Error!void {
            for (&self.value_mask.masks) |mask| try w.writeInt(usize, mask, .little);
        }
    };
}

pub fn VDBType(comptime V: type, comptime A: u5, comptime B: u5, comptime C: u5, comptime include_inside: bool) type {
    std.debug.assert(@sizeOf(V) <= @sizeOf(usize));
    return struct {
        const Self = @This();
        pub const Key = [3]i32;
        pub const Data = struct {
            child_off: ?usize,
            tile_value: V,
            active: bool,
        };
        pub const NodeA = InternalNode(V, A);
        pub const NodeB = InternalNode(V, B);
        pub const NodeC = LeafNode(C, include_inside);

        map: std.AutoArrayHashMapUnmanaged(Key, Data),
        nodes_A: std.ArrayListUnmanaged(NodeA),
        nodes_B: std.ArrayListUnmanaged(NodeB),
        nodes_C: std.ArrayListUnmanaged(NodeC),
        // VDB assumes ownership of these pointers
        values: std.ArrayListUnmanaged([]V),
        background: V,

        pub fn init(background: V) Self {
            return .{
                .map = .empty,
                .nodes_A = .empty,
                .nodes_B = .empty,
                .nodes_C = .empty,
                .values = .empty,
                .background = background,
            };
        }

        pub fn deinit(self: *Self, gpa: std.mem.Allocator) void {
            self.map.deinit(gpa);
            self.nodes_A.deinit(gpa);
            self.nodes_B.deinit(gpa);
            self.nodes_C.deinit(gpa);
            for (self.values.items) |arr| gpa.free(arr);
            self.values.deinit(gpa);
            self.* = undefined;
        }

        pub fn pointToKey(p: Point) Self.Key {
            const masked = p.maskLower(A + B + C);
            return .{ masked.x, masked.y, masked.z };
        }

        pub const Accessor = struct {
            pub const KV = struct {
                key: Point,
                value: usize,
            };
            a: ?KV,
            b: ?KV,
            c: ?KV,

            pub const Level = enum { a, b, c };
            pub const init: Accessor = .{ .a = null, .b = null, .c = null };

            // Pointers may become invalidated by modifications to the VDB
            pub fn getNodeCached(
                self: Accessor,
                vdb: *const Self,
                comptime which: Level,
                at: Point,
            ) error{CacheMiss}!switch (which) {
                .a => *NodeA,
                .b => *NodeB,
                .c => *NodeC,
            } {
                switch (which) {
                    .a => {
                        const a_key = at.maskLower(A + B + C);
                        const cached = self.a orelse return error.CacheMiss;
                        if (cached.key != a_key) return error.CacheMiss;
                        return &vdb.nodes_A.items[cached.value];
                    },
                    .b => {
                        const b_key = at.maskLower(B + C);
                        const cached = self.b orelse return error.CacheMiss;
                        if (cached.key != b_key) return error.CacheMiss;
                        return &vdb.nodes_B.items[cached.value];
                    },
                    .c => {
                        const c_key = at.maskLower(C);
                        const cached = self.c orelse return error.CacheMiss;
                        if (cached.key != c_key) return error.CacheMiss;
                        return &vdb.nodes_C.items[cached.value];
                    },
                }
            }

            pub fn getNode(
                self: *Accessor,
                vdb: *const Self,
                comptime which: Level,
                at: Point,
            ) error{ Tile, NoNode }!switch (which) {
                .a => *NodeA,
                .b => *NodeB,
                .c => *NodeC,
            } {
                return self.getNodeCached(vdb, which, at) catch switch (which) {
                    .a => {
                        self.a = null;
                        const key = pointToKey(at);
                        const data = vdb.map.get(key) orelse return error.NoNode;
                        if (!data.active) return error.NoNode;
                        const child = data.child_off orelse return error.Tile;
                        self.a = .{ .key = at.maskLower(A + B + C), .value = child };
                        return &vdb.nodes_A.items[child];
                    },
                    .b => {
                        self.b = null;
                        const a_node = try self.getNode(vdb, .a, at);
                        const a_off = at.offsetOf(A + B + C, B + C);
                        if (!a_node.child_mask.isSet(a_off)) return error.NoNode;
                        if (a_node.value_mask.isSet(a_off)) return error.Tile;
                        const child = a_node.data[a_off].child;
                        self.b = .{ .key = at.maskLower(B + C), .value = child };
                        return &vdb.nodes_B.items[child];
                    },
                    .c => {
                        self.c = null;
                        const b_node = try self.getNode(vdb, .b, at);
                        const b_off = at.offsetOf(B + C, C);
                        if (!b_node.child_mask.isSet(b_off)) return error.NoNode;
                        if (b_node.value_mask.isSet(b_off)) return error.Tile;
                        const child = b_node.data[b_off].child;
                        self.c = .{ .key = at.maskLower(C), .value = child };
                        return &vdb.nodes_C.items[child];
                    },
                };
            }

            pub fn get(self: *Accessor, vdb: *const Self, at: Point) V {
                const c_node = self.getNode(vdb, .c, at) catch |err| switch (err) {
                    error.Tile => {
                        const b_node = self.getNodeCached(vdb, .b, at) catch return tile: {
                            const a_node = self.getNodeCached(vdb, .a, at) catch {
                                const key = pointToKey(at);
                                const data = vdb.map.get(key).?; // we would have gotten NoNode otherwise
                                break :tile data.tile_value;
                            };
                            const a_off = at.offsetOf(A + B + C, B + C);
                            break :tile a_node.data[a_off].value;
                        };
                        const b_off = at.offsetOf(B + C, C);
                        return b_node.data[b_off].value;
                    },
                    error.NoNode => return vdb.background,
                };
                const c_off = at.offsetOf(C, 0);
                if (!c_node.value_mask.isSet(c_off)) return vdb.background; // no voxel present at coordinates
                if (c_node.flags.buf_count == 0 or c_node.flags.compressed) @panic("TODO"); // TODO: compression, multibuffering?
                return vdb.values.items[c_node.data_offset][c_off];
            }

            /// Returns error.Tile when the larger node containing the new tile is already a tile
            pub fn putTile(self: *Accessor, vdb: *Self, gpa: std.mem.Allocator, containing: Point, val: V, which: Level) (std.mem.Allocator.Error || error{Tile})!void {
                switch (which) {
                    .a => {
                        const key = pointToKey(containing);
                        const gop = try vdb.map.getOrPut(gpa, key);
                        gop.value_ptr.* = .{
                            .active = true,
                            .tile_value = val,
                            .child_off = null,
                        };
                    },
                    .b => {
                        const node = self.getNode(vdb, .a, containing) catch |err| switch (err) {
                            error.Tile => return error.Tile,
                            error.NoNode => a_node: {
                                const key = pointToKey(containing);
                                const a_node = try vdb.nodes_A.addOne(gpa);
                                a_node.* = .init(containing.maskLower(A + B + C));
                                try vdb.map.putNoClobber(gpa, key, .{
                                    .active = true,
                                    .child_off = vdb.nodes_A.items.len - 1,
                                    .tile_value = undefined,
                                });
                                self.a = .{ .key = containing.maskLower(A + B + C), .value = vdb.nodes_A.items.len - 1 };
                                break :a_node a_node;
                            },
                        };
                        const a_off = containing.offsetOf(A + B + C, B + C);
                        node.value_mask.set(a_off);
                        node.data[a_off] = .{ .tile = val };
                    },
                    .c => {
                        const node = self.getNode(vdb, .b, containing) catch |err| switch (err) {
                            error.Tile => return error.Tile,
                            error.NoNode => b_node: {
                                const a_node = self.getNodeCached(vdb, .a, containing) catch a_node: {
                                    const key = pointToKey(containing);
                                    const a_node = try vdb.nodes_A.addOne(gpa);
                                    a_node.* = .init(containing.maskLower(A + B + C));
                                    try vdb.map.putNoClobber(gpa, key, .{
                                        .active = true,
                                        .child_off = vdb.nodes_A.items.len - 1,
                                        .tile_value = undefined,
                                    });
                                    self.a = .{ .key = containing.maskLower(A + B + C), .value = vdb.nodes_A.items.len - 1 };
                                    break :a_node a_node;
                                };
                                const a_off = containing.offsetOf(A + B + C, B + C);
                                const b_node = try vdb.nodes_B.addOne(gpa);
                                b_node.* = .init(containing.maskLower(B + C));
                                a_node.child_mask.set(a_off);
                                a_node.data[a_off] = .{ .child = vdb.nodes_B.items.len - 1 };
                                break :b_node b_node;
                            },
                        };
                        const b_off = containing.offsetOf(B + C, C);
                        node.value_mask.set(b_off);
                        node.data[b_off] = .{ .tile = val };
                    },
                }
            }

            // FIXME: audit the sad paths
            pub fn putVoxel(self: *Accessor, vdb: *Self, gpa: std.mem.Allocator, at: Point, val: V) (std.mem.Allocator.Error || error{Tile})!void {
                const node = self.getNode(vdb, .c, at) catch |err| switch (err) {
                    error.Tile => return error.Tile,
                    error.NoNode => node: {
                        const b_node = self.getNodeCached(vdb, .b, at) catch b_node: {
                            const a_node = self.getNodeCached(vdb, .a, at) catch a_node: {
                                const key = pointToKey(at);
                                const a_node = try vdb.nodes_A.addOne(gpa);
                                a_node.* = .init(at.maskLower(A + B + C));
                                try vdb.map.putNoClobber(gpa, key, .{
                                    .active = true,
                                    .child_off = vdb.nodes_A.items.len - 1,
                                    .tile_value = undefined,
                                });
                                self.a = .{ .key = at.maskLower(A + B + C), .value = vdb.nodes_A.items.len - 1 };
                                break :a_node a_node;
                            };
                            const a_off = at.offsetOf(A + B + C, B + C);
                            const b_node = try vdb.nodes_B.addOne(gpa);
                            b_node.* = .init(at.maskLower(B + C));
                            a_node.child_mask.set(a_off);
                            a_node.data[a_off] = .{ .child = vdb.nodes_B.items.len - 1 };
                            break :b_node b_node;
                        };
                        const b_off = at.offsetOf(B + C, C);
                        const c_node = try vdb.nodes_C.addOne(gpa);
                        const size = 1 << C + C + C;
                        const ptr = try vdb.values.addOne(gpa);
                        const slice = try gpa.alloc(V, size);
                        ptr.* = slice;
                        c_node.* = .{
                            .data_offset = vdb.values.items.len - 1,
                            .flags = .init(at.maskLower(C)),
                        };
                        b_node.child_mask.set(b_off);
                        b_node.data[b_off] = .{ .child = vdb.nodes_C.items.len - 1 };
                        break :node c_node;
                    },
                };
                const off = at.offsetOf(C, 0);
                node.value_mask.set(off);
                vdb.values.items[node.data_offset][off] = val;
            }
        };

        /// returns self.background if no voxel is found
        /// prefer using an Accessor if doing multiple operations.
        pub fn get(self: *Self, at: Point) V {
            var accessor: Self.Accessor = .init;
            return accessor.get(self, at);
        }

        /// prefer using an Accessor if doing multiple operations.
        /// returns error.Tile if the region is already contained in a larger tile
        pub fn putTile(self: *Self, gpa: std.mem.Allocator, containing: Point, val: V, which: Accessor.Level) (std.mem.Allocator.Error || error{Tile})!void {
            var accessor: Self.Accessor = .init;
            return accessor.putTile(self, gpa, containing, val, which);
        }

        /// prefer using an Accessor if doing multiple operations.
        pub fn putVoxel(self: *Self, gpa: std.mem.Allocator, at: Point, val: V) (std.mem.Allocator.Error || error{Tile})!void {
            var accessor: Self.Accessor = .init;
            return accessor.putVoxel(self, gpa, at, val);
        }

        pub fn countTopTiles(self: *const Self) u32 {
            var num: u32 = 0;
            for (self.map.values()) |val| {
                if (val.child_off == null) num += 1;
            }
            return num;
        }

        pub fn countTopNodes(self: *const Self) u32 {
            var num: u32 = 0;
            for (self.map.values()) |val| {
                if (val.child_off != null) num += 1;
            }
            return num;
        }

        pub fn format(self: *const Self, w: *Writer) Writer.Error!void {
            try w.writeInt(u32, 1, .little); // value buffers per leaf node
            try w.writeAll(std.mem.asBytes(&self.background));
            try w.writeInt(u32, self.countTopTiles(), .little);
            try w.writeInt(u32, self.countTopNodes(), .little);
            // write tiles
            for (self.map.keys(), self.map.values()) |key, val| {
                if (val.child_off != null) continue;
                for (&key) |k| try w.writeInt(i32, k, .little); // origin
                try w.writeAll(std.mem.asBytes(&val.tile_value));
                try w.writeByte(@intFromBool(val.active));
            }
            // write children (topology)
            for (self.map.keys(), self.map.values()) |key, val| {
                const offset = val.child_off orelse continue;
                for (&key) |k| try w.writeInt(i32, k, .little); // origin
                const a_node = self.nodes_A.items[offset];
                try w.print("{f}", .{a_node});
                // write children
                var it = a_node.child_mask.iterator(.{ .direction = .forward, .kind = .set });
                while (it.next()) |active_child| {
                    const b_offset = a_node.data[active_child].child;
                    const b_node = self.nodes_B.items[b_offset];
                    try w.print("{f}", .{b_node});
                    var iit = b_node.child_mask.iterator(.{ .direction = .forward, .kind = .set });
                    while (iit.next()) |active_leaf| {
                        const c_offset = b_node.data[active_leaf].child;
                        const c_node = self.nodes_C.items[c_offset];
                        try w.print("{f}", .{c_node});
                    }
                }
            }
            // write children (values)
            for (self.map.values()) |val| {
                const a_offset = val.child_off orelse continue;
                const a_node = self.nodes_A.items[a_offset];
                var it = a_node.child_mask.iterator(.{ .direction = .forward, .kind = .set });
                while (it.next()) |active_child| {
                    const b_offset = a_node.data[active_child].child;
                    const b_node = self.nodes_B.items[b_offset];
                    var iit = b_node.child_mask.iterator(.{ .direction = .forward, .kind = .set });
                    while (iit.next()) |active_leaf| {
                        const c_offset = b_node.data[active_leaf].child;
                        const c_node = self.nodes_C.items[c_offset];
                        try w.print("{f}", .{c_node});
                        try w.writeByte(6); // TODO: this indicates no compression
                        const data = self.values.items[c_node.data_offset];
                        var iiit = c_node.value_mask.iterator(.{ .direction = .forward, .kind = .set });
                        var index: usize = 0;
                        while (iiit.next()) |entry| : (index = entry + 1) {
                            _ = try w.splatByte(0, @sizeOf(V) * (entry - index)); // inactive values are zero
                            try w.writeAll(std.mem.asBytes(&data[entry]));
                        }
                    }
                }
            }
        }
    };
}

fn alt(slice: []const u8) std.fmt.Alt([]const u8, struct {
    fn format(
        self: []const u8,
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        try writer.writeInt(u32, @intCast(self.len), .little);
        try writer.writeAll(self);
    }
}.format) {
    return .{ .data = slice };
}

fn writeMetadata(w: *Writer) Writer.Error!void {
    // lots of hard coded things that will by dynamic if we expand this!
    try w.writeInt(u32, 4, .little); // number of entries
    try w.print("{f}{f}{f}", .{ alt("class"), alt("string"), alt("unknown") });
    try w.print("{f}{f}{f}", .{ alt("file_compression"), alt("string"), alt("none") });
    try w.print("{f}{f}", .{ alt("is_saved_as_half_float"), alt("bool") });
    try w.writeInt(u32, 1, .little); // size of bool is larger than the boolean lol
    try w.writeByte(@intFromBool(false));
    try w.print("{f}{f}{f}", .{ alt("name"), alt("string"), alt("density") });
}

fn writeTransform(w: *Writer, affine: [4][4]f64) Writer.Error!void {
    try w.print("{f}", .{alt("AffineMap")});
    for (0..4) |i| {
        for (0..4) |j| {
            const f = affine[j][i];
            try w.writeAll(std.mem.asBytes(&f));
        }
    }
}

fn writeGrid(w: *Writer, vdb: *VDB, affine: [4][4]f64, offset: u64) Writer.Error!void {
    var counter: std.Io.Writer.Discarding = .init(&.{});
    //grid name (should be dynamic when doing multiple grids)
    try w.print("{f}", .{alt("density")});
    try counter.writer.print("{f}", .{alt("density")});

    // grid type
    // (this will probably always be 543 but who knows! precision should match source eventually
    try w.print("{f}", .{alt("Tree_float_5_4_3")});
    try counter.writer.print("{f}", .{alt("Tree_float_5_4_3")});

    // Indicate no instance parent
    try w.writeInt(u32, 0, .little);
    try counter.writer.writeInt(u32, 0, .little);

    //Grid descriptor stream position
    const position = offset + counter.fullCount() + (@sizeOf(u64) * 3);
    try w.writeInt(u64, position, .little);
    try w.writeInt(u64, 0, .little);
    try w.writeInt(u64, 0, .little);

    //no compression
    try w.writeInt(u32, 0, .little);

    try writeMetadata(w);
    try writeTransform(w, affine);
    try w.print("{f}", .{vdb});
}

pub fn writeVDB(w: *Writer, vdb: *VDB, affine: [4][4]f64) !void {
    var counter: std.Io.Writer.Discarding = .init(&.{});
    //Magic Number (needed it spells out BDV)
    try w.writeAll(&.{ ' ', 'B', 'D', 'V', 0, 0, 0, 0 });
    try counter.writer.writeAll(&.{ ' ', 'B', 'D', 'V', 0, 0, 0, 0 });

    //File Version
    try w.writeInt(u32, 224, .little);
    try counter.writer.writeInt(u32, 224, .little);

    //Library version (pretend OpenVDB 8.1)
    try w.writeInt(u32, 8, .little);
    try counter.writer.writeInt(u32, 8, .little);
    try w.writeInt(u32, 1, .little);
    try counter.writer.writeInt(u32, 1, .little);

    //no grid offsets
    try w.writeByte(0);
    try counter.writer.writeByte(0);

    // write UUID
    const uuid = uuidv4(); // Feel free to replace with your own
    try w.writeAll(&uuid);
    try counter.writer.writeAll(&uuid);

    //No Metadata for now
    try w.writeInt(u32, 0, .little);
    try counter.writer.writeInt(u32, 0, .little);

    //One Grid
    try w.writeInt(u32, 1, .little);
    try counter.writer.writeInt(u32, 0, .little);

    try writeGrid(w, vdb, affine, counter.fullCount());
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
//SECTION: writing frames

// Writes a static VDB frame to disk
pub fn writeFrame(
    vdb: *VDB,
    filename: []const u8,
    arena_alloc: std.mem.Allocator,
    transform: [4][4]f64,
) !std.array_list.Managed(u8) {
    // FIXME: the semantics of this function are awful
    const name = try save.versionName(filename, arena_alloc);
    const file = try std.fs.cwd().createFile(name.items, .{});
    defer file.close();

    var buf: [2048]u8 = undefined;
    var w: std.fs.File.Writer = .init(file, &buf);
    try writeVDB(&w.interface, vdb, transform);
    try w.end();
    return name; // this seems wrong
}

//SECTION: Tests:
const constants = @import("constants.zig");
const id_4x4 = constants.IdentityMatrix4x4;
const test_patterns = @import("test_patterns.zig");
//Use "tmp" to use the tmp folder in zig cache
pub fn sphereTest(comptime save_dir: []const u8) !void {
    //NICE: I think this is a good convention for allocators and arena allocators
    //FIX: upon using this, it's a little clunky. See nifti1.toVolume for a better option
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var buffer: std.Io.Writer.Allocating = .init(arena_alloc);
    defer buffer.deinit();
    const R: u32 = 128;
    const D: u32 = R * 2;
    var sphere_vdb = VDB.init(0);
    const Rf: f32 = @floatFromInt(R);
    const R2: f32 = Rf * Rf;
    for (0..D - 1) |z| {
        for (0..D - 1) |y| {
            for (0..D - 1) |x| {
                const p = toF32(.{ x, y, z });
                const diff = subVec(p, .{ Rf, Rf, Rf });
                if (lengthSquared(diff) < R2) {
                    try sphere_vdb.putVoxel(arena_alloc, .{ .x = @intCast(x), .y = @intCast(y), .z = @intCast(z) }, 1.0);
                }
            }
        }
    }
    try writeVDB(
        &buffer.writer,
        &sphere_vdb,
        id_4x4,
    );
    var arrlist = buffer.toArrayList();
    var managed = arrlist.toManaged(arena_alloc);
    try test_patterns.saveTestPattern(
        save_dir,
        "sphere_test_pattern",
        arena_alloc,
        &managed,
    );
}
pub fn oneVoxelTest(comptime save_dir: []const u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    var buffer: std.Io.Writer.Allocating = .init(arena_alloc);
    defer buffer.deinit();

    var single_voxel: VDB = .init(0);

    print("setting voxels\n", .{});
    try single_voxel.putVoxel(arena_alloc, .{ .x = 0, .y = 0, .z = 0 }, 1.0);
    try writeVDB(
        &buffer.writer,
        &single_voxel,
        id_4x4,
    ); // assumes compatible signature
    var arrlist = buffer.toArrayList();
    var managed = arrlist.toManaged(arena_alloc);
    try test_patterns.saveTestPattern(
        save_dir,
        "one_pixel_test_pattern",
        arena_alloc,
        &managed,
    );
}
const t = @import("timer.zig");
test "test patterns" {
    const s = t.Click();
    print("☁️ ⚪️ Sphere Test Pattern\n", .{});
    _ = t.Lap(s, "Sphere Test Pattern Timer");

    try sphereTest("tmp");
    print("☁️ ▫️ One Voxel Test Pattern\n", .{});
    try oneVoxelTest("tmp");
}
