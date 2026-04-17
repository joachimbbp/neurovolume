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
    z: i32,
    y: i32,
    x: i32,

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

    test offsetOf {
        const p: Point = .from(.{ 3, 7, 4 });
        const expected: u32 = (1 << 2) + (1 << 1) + 0;
        try std.testing.expectEqual(expected, p.offsetOf(2, 1));
    }

    pub fn compareUpper(p: Point, q: Point, comptime n: u5) bool {
        return p.maskLower(n) == q.maskLower(n);
    }

    test compareUpper {
        const p: Point = .{ .x = 69, .y = 67, .z = 137 };
        const q: Point = .{ .x = 0, .y = 0, .z = 0 };
        try std.testing.expect(p.compareUpper(q, 8));
        try std.testing.expect(!p.compareUpper(q, 7));
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

test VDB {
    _ = VDB;
}

fn equalTolerance(comptime V: type, a: V, b: V, tolerance: V) bool {
    if (tolerance == 0) return a == b;
    // if a is small, approxEqAbs works better
    if (std.math.approxEqAbs(V, 0, a, tolerance))
        return std.math.approxEqAbs(V, a, b, tolerance);
    return std.math.approxEqRel(V, a, b, tolerance);
}

pub fn InternalNode(comptime V: type, comptime N: u5) type {
    return struct {
        pub const dim = N + N + N;
        pub const size = 1 << dim;
        pub const Data = union {
            value: V,
            child: usize,
        };
        data: [size]Data,
        value_mask: Mask,
        child_mask: Mask,
        origin: Point,

        const Node = @This();
        const Mask = std.bit_set.ArrayBitSet(usize, size);

        pub fn isConstant(self: *const Node, tolerance: V) bool {
            if (self.child_mask.count() != 0) return false;
            const count = self.value_mask.count();
            if (count == 0) return true;
            if (count != self.value_mask.capacity()) return false;
            var it = self.iterateValues();
            const first = it.next().?;
            while (it.next()) |second|
                if (!equalTolerance(V, first, second, tolerance)) return false;
            return true;
        }

        pub const Iterator = struct {
            n: *const Node,
            it: Mask.Iterator(.{}),

            pub fn next(self: *Iterator) ?V {
                const idx = self.it.next() orelse return null;
                return self.n.data[idx].value;
            }
        };

        pub fn iterateValues(self: *const Node) Iterator {
            std.debug.assert(self.child_mask.intersectWith(self.value_mask).count() == 0); // child and value masks must be disjoint
            return .{
                .n = self,
                .it = self.value_mask.iterator(.{}),
            };
        }

        test isConstant {
            var node: Node = .init(.from(.{ 0, 0, 0 }));
            try std.testing.expect(node.isConstant(0));
            node.child_mask.set(0);
            try std.testing.expect(!node.isConstant(0));
            node.child_mask.unset(0);
            node.value_mask.set(0);
            try std.testing.expect(!node.isConstant(0));
            node.value_mask.unset(0);
            node.value_mask.toggleAll();
            node.data = @splat(.{ .value = 1 });
            try std.testing.expect(node.isConstant(0));
        }

        pub fn init(origin: Point) Node {
            return .{
                .data = undefined,
                .value_mask = .initEmpty(),
                .child_mask = .initEmpty(),
                .origin = origin,
            };
        }

        pub fn format(self: *const Node, w: *Writer) Writer.Error!void {
            std.debug.assert(self.child_mask.intersectWith(self.value_mask).count() == 0); // child mask and value mask must be disjoint
            try w.writeAll(@ptrCast(&self.child_mask.masks));
            try w.writeAll(@ptrCast(&self.value_mask.masks));
            // FIXME: compression?
            try w.writeByte(6);
            for (0..self.value_mask.capacity()) |i| {
                if (self.value_mask.isSet(i))
                    try w.writeAll(std.mem.asBytes(&self.data[i].value))
                else
                    try w.splatByteAll(0, @sizeOf(V));
            }
        }

        test format {
            const n: Node = .init(.from(.{ 0, 0, 0 }));
            var w: std.Io.Writer.Discarding = .init(&.{});
            try w.writer.print("{f}", .{&n});
            try std.testing.expectEqual((size / 8) + (size / 8) + 1 + (size * @sizeOf(V)), w.fullCount());
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

                pub fn toPoint(self: @This()) Point {
                    return .{
                        .x = self.x << N,
                        .y = self.y << N,
                        .z = self.z << N,
                    };
                }
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
            try w.writeAll(@ptrCast(&self.value_mask.masks));
        }

        pub fn prune(self: *@This(), comptime V: type, data: []const V, background: V, tolerance: V) void {
            var it = self.value_mask.iterator(.{});
            while (it.next()) |i| {
                if (equalTolerance(V, background, data[i], tolerance)) self.value_mask.unset(i);
            }
        }

        pub fn isConstant(self: *const @This(), comptime V: type, data: []const V, tolerance: V) bool {
            const count = self.value_mask.count();
            if (count == 0) return true;
            if (count != self.value_mask.capacity()) return false;
            const first = data[0];
            for (data) |second| if (!equalTolerance(V, first, second, tolerance)) return false;
            return true;
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
        // TODO: if V is allowed to be non-float, this needs changing
        pub const kind: []const u8 = std.fmt.comptimePrint("Tree_float_{d}_{d}_{d}", .{ A, B, C });

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

        pub fn Iterator(comptime which: Level) type {
            return struct {
                vdb: *const Self,
                parent: switch (which) {
                    .a => []const Data,
                    .b => *NodeA,
                    .c => *NodeB,
                },
                it: switch (which) {
                    .a => usize,
                    .b => NodeA.Mask.Iterator(.{}),
                    .c => NodeB.Mask.Iterator(.{}),
                },
                n: usize,

                const Which = switch (which) {
                    .a => *NodeA,
                    .b => *NodeB,
                    .c => *NodeC,
                };

                pub fn next(self: *@This()) ?Which {
                    if (comptime which == .a) {
                        while (self.it < self.parent.len) {
                            const dat = self.parent[self.it];
                            self.n = self.it;
                            self.it += 1;
                            const offset = dat.child_off orelse continue;
                            if (!dat.active) continue;
                            return &self.vdb.nodes_A.items[offset];
                        }
                        return null;
                    }
                    const idx = self.it.next() orelse return null;
                    self.n = idx;
                    return switch (which) {
                        .a => comptime unreachable,
                        .b => &self.vdb.nodes_B.items[self.parent.data[idx].child],
                        .c => &self.vdb.nodes_C.items[self.parent.data[idx].child],
                    };
                }
            };
        }

        pub fn iterateChildren(self: *const Self, comptime which: Level, of: switch (which) {
            .a => void,
            .b => *NodeA,
            .c => *NodeB,
        }) Iterator(which) {
            return .{
                .vdb = self,
                .parent = switch (which) {
                    .a => self.map.values(),
                    else => of,
                },
                .it = switch (which) {
                    .a => 0,
                    else => of.child_mask.iterator(.{}),
                },
                .n = 0,
            };
        }

        pub const Level = enum { a, b, c };

        pub const Accessor = struct {
            point: Point,
            a: ?usize,
            b: ?usize,
            c: ?usize,

            pub const init: Accessor = .{ .point = undefined, .a = null, .b = null, .c = null };

            // Pointers may become invalidated by modifications to the VDB
            pub fn getNodeCached(
                self: Accessor,
                vdb: *const Self,
                comptime which: Level,
                at: Point,
            ) switch (which) {
                .a => ?*NodeA,
                .b => ?*NodeB,
                .c => ?*NodeC,
            } {
                switch (which) {
                    .a => {
                        const cached = self.a orelse return null;
                        if (!self.point.compareUpper(at, A + B + C)) return null;
                        return &vdb.nodes_A.items[cached];
                    },
                    .b => {
                        const cached = self.b orelse return null;
                        if (!self.point.compareUpper(at, B + C)) return null;
                        return &vdb.nodes_B.items[cached];
                    },
                    .c => {
                        const cached = self.c orelse return null;
                        if (!self.point.compareUpper(at, C)) return null;
                        return &vdb.nodes_C.items[cached];
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
                return self.getNodeCached(vdb, which, at) orelse {
                    switch (which) {
                        .a => {
                            self.a = null;
                            const key = pointToKey(at);
                            const data = vdb.map.get(key) orelse return error.NoNode;
                            const child = data.child_off orelse {
                                if (!data.active) return error.NoNode;
                                return error.Tile;
                            };
                            self.a = child;
                            self.point = at;
                            return &vdb.nodes_A.items[child];
                        },
                        .b => {
                            self.b = null;
                            const a_node = try self.getNode(vdb, .a, at);
                            const a_off = at.offsetOf(A + B + C, B + C);
                            if (a_node.value_mask.isSet(a_off)) return error.Tile;
                            if (!a_node.child_mask.isSet(a_off)) return error.NoNode;
                            const child = a_node.data[a_off].child;
                            self.b = child;
                            self.point = at;
                            return &vdb.nodes_B.items[child];
                        },
                        .c => {
                            self.c = null;
                            const b_node = try self.getNode(vdb, .b, at);
                            const b_off = at.offsetOf(B + C, C);
                            if (b_node.value_mask.isSet(b_off)) return error.Tile;
                            if (!b_node.child_mask.isSet(b_off)) return error.NoNode;
                            const child = b_node.data[b_off].child;
                            self.c = child;
                            self.point = at;
                            return &vdb.nodes_C.items[child];
                        },
                    }
                };
            }

            pub fn get(self: *Accessor, vdb: *const Self, at: Point) V {
                const c_node = self.getNode(vdb, .c, at) catch |err| switch (err) {
                    error.Tile => {
                        const b_node = self.getNodeCached(vdb, .b, at) orelse return tile: {
                            const a_node = self.getNodeCached(vdb, .a, at) orelse {
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
                                const gop = try vdb.map.getOrPut(gpa, key);
                                gop.value_ptr.* = .{
                                    .active = true,
                                    .child_off = vdb.nodes_A.items.len,
                                    .tile_value = undefined,
                                };
                                const a_node = try vdb.nodes_A.addOne(gpa);
                                a_node.* = .init(containing.maskLower(A + B + C));
                                self.a = vdb.nodes_A.items.len - 1;
                                break :a_node a_node;
                            },
                        };
                        const a_off = containing.offsetOf(A + B + C, B + C);
                        node.child_mask.unset(a_off);
                        node.value_mask.set(a_off);
                        node.data[a_off] = .{ .value = val };
                    },
                    .c => {
                        const node = self.getNode(vdb, .b, containing) catch |err| switch (err) {
                            error.Tile => return error.Tile,
                            error.NoNode => b_node: {
                                const a_node = self.getNodeCached(vdb, .a, containing) orelse a_node: {
                                    const key = pointToKey(containing);
                                    const gop = try vdb.map.getOrPut(gpa, key);
                                    gop.value_ptr.* = .{
                                        .active = true,
                                        .child_off = vdb.nodes_A.items.len,
                                        .tile_value = undefined,
                                    };
                                    const a_node = try vdb.nodes_A.addOne(gpa);
                                    a_node.* = .init(containing.maskLower(A + B + C));
                                    self.a = vdb.nodes_A.items.len - 1;
                                    break :a_node a_node;
                                };
                                const a_off = containing.offsetOf(A + B + C, B + C);
                                a_node.child_mask.set(a_off);
                                a_node.data[a_off] = .{ .child = vdb.nodes_B.items.len };
                                const b_node = try vdb.nodes_B.addOne(gpa);
                                b_node.* = .init(containing.maskLower(B + C));
                                self.b = vdb.nodes_B.items.len - 1;
                                break :b_node b_node;
                            },
                        };
                        const b_off = containing.offsetOf(B + C, C);
                        node.child_mask.unset(b_off);
                        node.value_mask.set(b_off);
                        node.data[b_off] = .{ .value = val };
                    },
                }
            }

            // FIXME: audit the sad paths
            pub fn putVoxel(self: *Accessor, vdb: *Self, gpa: std.mem.Allocator, at: Point, val: V) (std.mem.Allocator.Error || error{Tile})!void {
                // special case: don't create voxels for the background value
                if (val == vdb.background) return;
                const node = self.getNode(vdb, .c, at) catch |err| switch (err) {
                    error.Tile => return error.Tile,
                    error.NoNode => node: {
                        const b_node = self.getNodeCached(vdb, .b, at) orelse b_node: {
                            const a_node = self.getNodeCached(vdb, .a, at) orelse a_node: {
                                const key = pointToKey(at);
                                const a_node = try vdb.nodes_A.addOne(gpa);
                                a_node.* = .init(at.maskLower(A + B + C));
                                const gop = try vdb.map.getOrPut(gpa, key);
                                gop.value_ptr.* = .{
                                    .active = true,
                                    .child_off = vdb.nodes_A.items.len - 1,
                                    .tile_value = undefined,
                                };
                                self.a = vdb.nodes_A.items.len - 1;
                                self.point = at;
                                break :a_node a_node;
                            };
                            const a_off = at.offsetOf(A + B + C, B + C);
                            const b_node = try vdb.nodes_B.addOne(gpa);
                            b_node.* = .init(at.maskLower(B + C));
                            a_node.child_mask.set(a_off);
                            a_node.data[a_off] = .{ .child = vdb.nodes_B.items.len - 1 };
                            self.b = vdb.nodes_B.items.len - 1;
                            self.point = at;
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
                        self.c = vdb.nodes_C.items.len - 1;
                        self.point = at;
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
        pub fn putTile(self: *Self, gpa: std.mem.Allocator, containing: Point, val: V, which: Level) (std.mem.Allocator.Error || error{Tile})!void {
            var accessor: Self.Accessor = .init;
            return accessor.putTile(self, gpa, containing, val, which);
        }

        /// prefer using an Accessor if doing multiple operations.
        pub fn putVoxel(self: *Self, gpa: std.mem.Allocator, at: Point, val: V) (std.mem.Allocator.Error || error{Tile})!void {
            var accessor: Self.Accessor = .init;
            return accessor.putVoxel(self, gpa, at, val);
        }

        /// creates and returns a new VDB which has all of the data reachable from the current VDB
        pub fn dupe(self: *const Self, gpa: std.mem.Allocator) std.mem.Allocator.Error!Self {
            var vdb: Self = .init(self.background);
            for (self.map.keys(), self.map.values()) |key, val| {
                if (val.child_off == null and !val.active) continue;
                const gop = try vdb.map.getOrPut(gpa, key);
                gop.value_ptr.* = val;
                const old_a_node = &self.nodes_A.items[val.child_off orelse continue];
                gop.value_ptr.child_off = vdb.nodes_A.items.len;
                const new_a_node = try vdb.nodes_A.addOne(gpa);
                new_a_node.* = old_a_node.*;
                std.debug.assert(old_a_node.child_mask.intersectWith(old_a_node.value_mask).count() == 0);
                var b_it = self.iterateChildren(.b, old_a_node);
                while (b_it.next()) |old_b_node| {
                    new_a_node.data[b_it.n] = .{ .child = vdb.nodes_B.items.len };
                    const new_b_node = try vdb.nodes_B.addOne(gpa);
                    new_b_node.* = old_b_node.*;
                    std.debug.assert(old_b_node.child_mask.intersectWith(old_b_node.value_mask).count() == 0);
                    var c_it = self.iterateChildren(.c, old_b_node);
                    while (c_it.next()) |old_c_node| {
                        new_b_node.data[c_it.n] = .{ .child = vdb.nodes_C.items.len };
                        const new_c_node = try vdb.nodes_C.addOne(gpa);
                        new_c_node.* = old_c_node.*;
                        new_c_node.data_offset = vdb.values.items.len;
                        const new_data_ptr = try vdb.values.addOne(gpa);
                        new_data_ptr.* = try gpa.dupe(V, self.values.items[old_c_node.data_offset]);
                    }
                }
            }
            return vdb;
        }

        /// replaces nodes whose values are all constant with tiles
        /// leaves "dangling" nodes; call dupe afterward to produce a new tree without dangling nodes
        pub fn prune(self: *Self, tolerance: V) void {
            var a_it = self.iterateChildren(.a, {});
            while (a_it.next()) |a_node| {
                var b_it = self.iterateChildren(.b, a_node);
                while (b_it.next()) |b_node| {
                    var c_it = self.iterateChildren(.c, b_node);
                    while (c_it.next()) |c_node| {
                        const data = self.values.items[c_node.data_offset];
                        c_node.prune(V, data, self.background, tolerance);
                        if (c_node.isConstant(V, data, tolerance)) {
                            b_node.child_mask.unset(c_it.n);
                            if (c_node.value_mask.count() != 0) {
                                b_node.value_mask.set(c_it.n);
                                b_node.data[c_it.n] = .{ .value = data[0] };
                            }
                        }
                    }
                    if (b_node.isConstant(tolerance)) {
                        a_node.child_mask.unset(b_it.n);
                        if (b_node.value_mask.count() != 0) {
                            a_node.value_mask.set(b_it.n);
                            a_node.data[b_it.n] = .{ .value = b_node.data[0].value };
                        }
                    }
                }
                if (a_node.isConstant(tolerance)) {
                    const count = a_node.value_mask.count();
                    self.map.values()[a_it.n] = .{
                        .active = count != 0,
                        .child_off = null,
                        .tile_value = if (count == 0) undefined else a_node.data[0].value,
                    };
                }
            }
        }

        test prune {
            var vdb: Self = .init(0);
            const gpa = std.testing.allocator;
            defer vdb.deinit(gpa);
            const p: Point = .from(.{ 0, 0, 0 });
            try vdb.putVoxel(gpa, p, 1);
            vdb.prune(0);
            var accessor: Accessor = .init;
            try std.testing.expectEqual(1, accessor.get(&vdb, p));
            {
                const c_node = accessor.getNodeCached(&vdb, .c, p).?;
                const b_node = accessor.getNodeCached(&vdb, .b, p).?;
                const a_node = accessor.getNodeCached(&vdb, .a, p).?;
                try std.testing.expectEqual(1, c_node.value_mask.count());
                try std.testing.expectEqual(1, b_node.child_mask.count() + b_node.value_mask.count());
                try std.testing.expectEqual(1, a_node.child_mask.count() + a_node.value_mask.count());
                try std.testing.expectEqual(0, vdb.countTopTiles());
                try std.testing.expectEqual(1, vdb.countTopNodes());
                c_node.value_mask.unset(0);
            }
            vdb.prune(0);
            accessor = .init;
            try std.testing.expectEqual(0, accessor.get(&vdb, p));
            try std.testing.expectEqual(0, vdb.countTopTiles());
            try std.testing.expectEqual(0, vdb.countTopNodes());
            vdb.deinit(gpa);
            vdb = .init(0);
            try vdb.putTile(gpa, p, 1, .c);
            vdb.prune(0);
            accessor = .init;
            try std.testing.expectEqual(1, accessor.get(&vdb, p));
            try std.testing.expectEqual(0, vdb.countTopTiles());
            try std.testing.expectEqual(1, vdb.countTopNodes());
            const b_node = accessor.getNodeCached(&vdb, .b, p).?;
            try std.testing.expectEqual(1, b_node.value_mask.count());
            try std.testing.expectEqual(0, b_node.child_mask.count());
            b_node.child_mask.set(0);
            b_node.value_mask.unset(0);
            b_node.data[0] = .{ .child = vdb.nodes_C.items.len };
            const c_node = try vdb.nodes_C.addOne(gpa);
            c_node.* = .{ .flags = .init(p), .data_offset = vdb.values.items.len };
            const data = try vdb.values.addOne(gpa);
            data.* = try gpa.alloc(V, NodeC.size);
            @memset(data.*, 2);
            data.*[0] = 1;
            c_node.value_mask.toggleAll();
            vdb.prune(0);
            accessor = .init;
            try std.testing.expectEqual(1, accessor.get(&vdb, p));
            _ = try accessor.getNode(&vdb, .c, p);
            data.*[0] = 2;
            vdb.prune(0);
            accessor = .init;
            try std.testing.expectEqual(2, accessor.get(&vdb, p));
            try std.testing.expectError(error.Tile, accessor.getNode(&vdb, .c, p));
        }

        pub fn countTopTiles(self: *const Self) u32 {
            var num: u32 = 0;
            for (self.map.values()) |val| {
                if (val.child_off == null and val.active) num += 1;
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

        /// writes the topology for this tree
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
                if (!val.active) continue;
                for (&key) |k| try w.writeInt(i32, k, .little); // origin
                var c: std.Io.Writer.Discarding = .init(&.{});
                const p = &c.writer;
                for (&key) |k| try p.writeInt(i32, k, .little); // origin
                const a_node = &self.nodes_A.items[offset];
                try w.print("{f}", .{a_node});
                try p.print("{f}", .{a_node});
                var count = c.fullCount();
                count = c.fullCount();
                if (count != 12 + 4096 + 4096 + 1 + 131_072) std.debug.panic("diff: {d}", .{count});
                // write children
                var a_it = self.iterateChildren(.b, a_node);
                while (a_it.next()) |b_node| {
                    try w.print("{f}", .{b_node});
                    try p.print("{f}", .{b_node});
                    const b_diff = c.fullCount() - count;
                    count = c.fullCount();
                    std.debug.assert(512 + 512 + 1 + 16_384 == b_diff);
                    var b_it = self.iterateChildren(.c, b_node);
                    while (b_it.next()) |c_node| {
                        try w.print("{f}", .{c_node});
                        try p.print("{f}", .{c_node});
                        const c_diff = c.fullCount() - count;
                        count = c.fullCount();
                        std.debug.assert(c_diff == 64);
                    }
                }
            }
        }

        /// writes the data values for this tree
        pub fn blockData(vdb: *const Self) std.fmt.Alt(*const Self, struct {
            pub fn format(self: *const Self, w: *Writer) Writer.Error!void {
                // write children (values)
                for (self.map.values()) |val| {
                    const a_offset = val.child_off orelse continue;
                    if (!val.active) continue;
                    const a_node = &self.nodes_A.items[a_offset];
                    var a_it = self.iterateChildren(.b, a_node);
                    while (a_it.next()) |b_node| {
                        var b_it = self.iterateChildren(.c, b_node);
                        while (b_it.next()) |c_node| {
                            try w.print("{f}", .{c_node});
                            try w.writeByte(6); // TODO: this indicates no compression
                            const dat = self.values.items[c_node.data_offset];
                            switch (@import("builtin").mode) {
                                .Debug => {
                                    for (0..c_node.value_mask.capacity()) |i| {
                                        if (c_node.value_mask.isSet(i))
                                            try w.writeAll(std.mem.asBytes(&dat[i]))
                                        else
                                            try w.splatByteAll(0, @sizeOf(V));
                                    }
                                },
                                else => { // in Release modes, we write the bytes directly
                                    try w.writeAll(@ptrCast(dat));
                                },
                            }
                        }
                    }
                }
            }
        }.format) {
            return .{ .data = vdb };
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

const vdb_magic: []const u8 = &.{ ' ', 'B', 'D', 'V', 0, 0, 0, 0 };
const Metadatum = union(enum) {
    // TODO: allow more metadata types
    string: []const u8,
    boolean: bool,

    pub fn format(data: Metadatum, w: *std.Io.Writer) std.Io.Writer.Error!void {
        try w.print("{f}", .{alt(switch (data) {
            .string => "string",
            .boolean => "bool",
        })});
        switch (data) {
            .string => |str| try w.print("{f}", .{alt(str)}),
            .boolean => |b| {
                try w.writeInt(u32, 1, .little);
                try w.writeByte(@intFromBool(b));
            },
        }
    }

    pub fn deinit(d: *Metadatum, allocator: std.mem.Allocator) void {
        switch (d.*) {
            .boolean => return,
            .string => |str| allocator.free(str),
        }
    }
};
pub fn GridType(comptime vdb_type: type) type {
    return struct {
        tree: *vdb_type,
        name: []const u8,
        grid_position: i64,
        block_position: i64,
        end_position: i64,
        transform: [4][4]f64,
        metadata: MetaMap,

        pub const kind = vdb_type.kind;
        const Self = @This();

        pub fn init(tree: *vdb_type, name: []const u8, transform: [4][4]f64, metadata: MetaMap) Self {
            return .{
                .tree = tree,
                .name = name,
                .transform = transform,
                .metadata = metadata,
                .block_position = 0,
                .end_position = 0,
                .grid_position = 0,
            };
        }

        pub fn addDefaultMetadata(grid: *Self, gpa: std.mem.Allocator) !void {
            try grid.metadata.put(gpa, "class", .{ .string = try gpa.dupe(u8, "unknown") });
            try grid.metadata.put(gpa, "file_compression", .{ .string = try gpa.dupe(u8, "none") });
            try grid.metadata.put(gpa, "is_saved_as_half_float", .{ .boolean = false });
        }

        /// Grids do not own their tree or name,
        /// so you must call grid.tree.deinit() separately to prevent leaks.
        pub fn deinit(g: *Self, allocator: std.mem.Allocator) void {
            for (g.metadata.values()) |*val| val.deinit(allocator);
            g.metadata.deinit(allocator);
            g.* = undefined;
        }

        pub fn writeTopology(g: Self, w: *std.Io.Writer) Writer.Error!void {
            try w.print("{f}", .{g.tree});
        }
        pub fn writeData(g: Self, w: *std.Io.Writer) Writer.Error!void {
            try w.print("{f}", .{g.tree.blockData()});
        }

        pub fn writeTransform(g: Self, w: *Writer) Writer.Error!void {
            try w.print("{f}", .{alt("AffineMap")});
            for (0..4) |i| {
                for (0..4) |j| {
                    const f = g.transform[j][i];
                    try w.writeAll(std.mem.asBytes(&f));
                }
            }
        }

        pub fn writeHeader(_: Self, writer: *std.Io.Writer, name: []const u8, other_name: []const u8) Writer.Error!void {
            try writer.print("{f}", .{alt(name)});
            try writer.print("{f}", .{alt(Self.kind)});
            try writer.print("{f}", .{alt(other_name)});
        }

        fn writePositions(grid: Self, writer: *std.Io.Writer) Writer.Error!void {
            try writer.writeInt(i64, grid.grid_position, .little);
            try writer.writeInt(i64, grid.block_position, .little);
            try writer.writeInt(i64, grid.end_position, .little);
        }

        pub fn writeInstance(
            grid: *Self,
            file: *std.fs.File.Writer,
            name: []const u8,
            other_name: []const u8,
        ) !void {
            try grid.writeHeader(&file.interface, name, other_name);
            const offset = logicalPos(file);
            try grid.writePositions(&file.interface);
            grid.grid_position = @intCast(logicalPos(file));
            try writeMetadata(&file.interface, grid.metadata);
            try grid.writeTransform(&file.interface);
            grid.end_position = @intCast(logicalPos(file));
            const end = logicalPos(file);
            try file.end(); // needed in order to seek
            try file.seekTo(offset);
            try grid.writePositions(&file.interface);
            try file.end(); // needed in order to seek
            try file.seekTo(end);
        }

        fn write(grid: *Self, file: *std.fs.File.Writer, name: []const u8) !void {
            try grid.writeHeader(&file.interface, name, "");
            const offset = logicalPos(file);
            try grid.writePositions(&file.interface);
            grid.grid_position = @intCast(logicalPos(file));
            try writeMetadata(&file.interface, grid.metadata);
            try grid.writeTransform(&file.interface);
            try grid.writeTopology(&file.interface);
            grid.block_position = @intCast(logicalPos(file));
            try grid.writeData(&file.interface);
            grid.end_position = @intCast(logicalPos(file));
            const end = logicalPos(file);
            try file.end(); // needed in order to seek
            try file.seekTo(offset);
            try grid.writePositions(&file.interface);
            try file.end(); // needed in order to seek
            try file.seekTo(end);
        }
    };
}
pub const Grid = GridType(VDB);
pub const MetaMap = std.StringArrayHashMapUnmanaged(Metadatum);

// FIXME: remove this function in favor of file.logicalPos() after updating to Zig 0.16
fn logicalPos(file: *const std.fs.File.Writer) u64 {
    return file.pos + file.interface.end;
}

fn writeMetadata(w: *Writer, map: MetaMap) !void {
    // metadata count
    try w.writeInt(u32, @intCast(map.count()), .little);
    var it = map.iterator();
    while (it.next()) |entry| {
        std.debug.assert(entry.key_ptr.len > 0);
        try w.print("{f}", .{alt(entry.key_ptr.*)});
        try w.print("{f}", .{entry.value_ptr.*});
    }
}

pub fn writeVDBFile(
    file: *std.fs.File.Writer,
    scratch: std.mem.Allocator,
    grids: []Grid,
    file_metadata: MetaMap,
) !void {
    // magic number
    try file.interface.writeAll(vdb_magic);
    // file version
    try file.interface.writeInt(u32, 224, .little);
    // library version (matching OpenVDB 8.1)
    try file.interface.writeInt(u32, 8, .little);
    try file.interface.writeInt(u32, 1, .little);
    // grid offsets
    try file.interface.writeByte(1);
    // UUID
    const uuid = uuidv4();
    try file.interface.writeAll(&uuid);

    // metadata
    try writeMetadata(&file.interface, file_metadata);

    // grid count
    try file.interface.writeInt(u32, @intCast(grids.len), .little);

    // collect and disambiguate names
    const names: [][]const u8 = try scratch.alloc([]const u8, grids.len);
    defer scratch.free(names);
    var w: std.Io.Writer.Allocating = .init(scratch);
    var histogram: std.StringHashMapUnmanaged(struct { count: u32, current: u32 }) = .empty;
    defer histogram.deinit(scratch);
    for (grids) |grid| {
        const gop = try histogram.getOrPut(scratch, grid.name);
        if (gop.found_existing) gop.value_ptr.count += 1 else gop.value_ptr.* = .{ .count = 1, .current = 0 };
    }
    for (grids, names) |grid, *name| {
        const hist = histogram.getPtr(grid.name).?;
        if (grid.name.len == 0 or hist.count > 1) {
            try w.writer.print("{s}\x1e{d}", .{ grid.name, hist.current });
            hist.current += 1;
            name.* = try w.toOwnedSlice();
        } else name.* = try scratch.dupe(u8, grid.name);
    }
    w.deinit();
    defer for (names) |name| scratch.free(name);

    // write out the grids
    for (grids, names, 0..) |*grid, unique_name, i| {
        for (grids[0..i], names[0..i]) |other, other_name| {
            if (other.tree == grid.tree) {
                try grid.writeInstance(file, unique_name, other_name);
            }
            break;
        } else try grid.write(file, unique_name);
    }
    try file.end();
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
    var g: Grid = .init(vdb, "density", transform, .empty);
    try g.addDefaultMetadata(arena_alloc);
    try writeVDBFile(&w, arena_alloc, &.{g}, .empty);
    return name; // this seems wrong
}
