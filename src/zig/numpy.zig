//DISCLAIMER:
// this entire module is claude copypasta!

const std = @import("std");

pub const NpyArray = struct {
    data: []u8,
    shape: []usize, //jbbp: I believe t x y z
    dtype: []u8,
    fortran_order: bool,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *NpyArray) void {
        self.allocator.free(self.data);
        self.allocator.free(self.shape);
        self.allocator.free(self.dtype);
    }
};

pub fn loadNpy(allocator: std.mem.Allocator, path: []const u8) !NpyArray {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    // 1. Verify magic bytes: "\x93NUMPY"
    var magic: [6]u8 = undefined;
    _ = try file.read(&magic);
    if (!std.mem.eql(u8, &magic, "\x93NUMPY"))
        return error.InvalidMagic;

    // 2. Version (major, minor)
    var version: [2]u8 = undefined;
    _ = try file.read(&version);

    // 3. Header length (little-endian u16 for v1.0, u32 for v2.0)
    const header_len: u32 = if (version[0] == 1) blk: {
        var buf: [2]u8 = undefined;
        _ = try file.read(&buf);
        break :blk std.mem.readInt(u16, &buf, .little);
    } else blk: {
        var buf: [4]u8 = undefined;
        _ = try file.read(&buf);
        break :blk std.mem.readInt(u32, &buf, .little);
    };

    // 4. Read header string
    const header = try allocator.alloc(u8, header_len);
    defer allocator.free(header);
    _ = try file.read(header);

    // 5. Parse header fields
    const dtype = try parseDtype(allocator, header);
    const fortran_order = parseFortranOrder(header);
    const shape = try parseShape(allocator, header);

    // 6. Calculate element size from dtype
    const elem_size = dtypeSize(dtype);

    // 7. Calculate total elements
    var total: usize = 1;
    for (shape) |dim| total *= dim;

    // 8. Read raw data
    const data = try allocator.alloc(u8, total * elem_size);
    _ = try file.readAll(data);

    return NpyArray{
        .data = data,
        .shape = shape,
        .dtype = dtype,
        .fortran_order = fortran_order,
        .allocator = allocator,
    };
}

// Cast raw bytes to a typed slice
pub fn asSlice(comptime T: type, array: NpyArray) []T {
    return std.mem.bytesAsSlice(T, @alignCast(array.data));
}

fn parseDtype(allocator: std.mem.Allocator, header: []const u8) ![]u8 {
    const key = "'descr': '";
    const start = (std.mem.indexOf(u8, header, key) orelse return error.NoDtype) + key.len;
    const end = std.mem.indexOf(u8, header[start..], "'") orelse return error.NoDtype;
    return allocator.dupe(u8, header[start .. start + end]);
}

fn parseFortranOrder(header: []const u8) bool {
    return std.mem.indexOf(u8, header, "True") != null;
}

fn parseShape(allocator: std.mem.Allocator, header: []const u8) ![]usize {
    const key = "'shape': (";
    const start = (std.mem.indexOf(u8, header, key) orelse return error.NoShape) + key.len;
    const end = std.mem.indexOf(u8, header[start..], ")") orelse return error.NoShape;
    const shape_str = header[start .. start + end];

    var dims: std.ArrayListUnmanaged(usize) = .{};
    defer dims.deinit(allocator);
    var iter = std.mem.splitScalar(u8, shape_str, ',');
    while (iter.next()) |part| {
        const trimmed = std.mem.trim(u8, part, " ");
        if (trimmed.len == 0) continue;
        try dims.append(allocator, try std.fmt.parseInt(usize, trimmed, 10));
    }
    return dims.toOwnedSlice(allocator);
}
fn dtypeSize(dtype: []const u8) usize {
    // Last char(s) are the byte count: '<f4' -> 4, '<i8' -> 8
    if (dtype.len == 0) return 0;
    return std.fmt.parseInt(usize, dtype[dtype.len - 1 ..], 10) catch 0;
}

pub fn loadAsF32Slice(allocator: std.mem.Allocator, path: []const u8) ![]f32 {
    var arr = try loadNpy(allocator, path);
    defer arr.deinit();

    const floats = std.mem.bytesAsSlice(f32, @alignCast(arr.data));
    return allocator.dupe(f32, floats);
}

/// Transpose, convert to f32, and normalize to [0,1].
/// `transpose` is a slice of axis indices, e.g. &[_]usize{2, 0, 1}
/// Caller owns the returned slice.
pub fn prepNdarray(
    allocator: std.mem.Allocator,
    array: NpyArray,
    transpose: []const usize,
) ![]f32 {
    const ndim = array.shape.len;
    std.debug.assert(transpose.len == ndim);

    // Build transposed shape
    const t_shape = try allocator.alloc(usize, ndim);
    defer allocator.free(t_shape);
    for (transpose, 0..) |ax, i| t_shape[i] = array.shape[ax];

    // Total element count
    var total: usize = 1;
    for (t_shape) |d| total *= d;

    const out = try allocator.alloc(f32, total);
    errdefer allocator.free(out);

    // Source must be f32 (dtype "<f4" or ">f4")

    const src = std.mem.bytesAsSlice(
        f32,
        @as([]align(@alignOf(f32)) u8, @alignCast(array.data)),
    );

    // Compute strides for the ORIGINAL shape (C-order, row-major)
    const src_strides = try allocator.alloc(usize, ndim);
    defer allocator.free(src_strides);
    {
        var s: usize = 1;
        var i: usize = ndim;
        while (i > 0) {
            i -= 1;
            src_strides[i] = s;
            s *= array.shape[i];
        }
    }

    // Walk every output index in C-order and copy from transposed source index
    var out_idx: usize = 0;
    var coords = try allocator.alloc(usize, ndim);
    defer allocator.free(coords);
    @memset(coords, 0);

    while (out_idx < total) : (out_idx += 1) {
        // Compute flat source index via transposed axis mapping
        var src_idx: usize = 0;
        for (0..ndim) |i| src_idx += coords[i] * src_strides[transpose[i]];

        out[out_idx] = src[src_idx];

        // Increment coords (C-order carry)
        var dim: usize = ndim;
        while (dim > 0) {
            dim -= 1;
            coords[dim] += 1;
            if (coords[dim] < t_shape[dim]) break;
            coords[dim] = 0;
        }
    }

    // Normalize to [0, 1]
    var max_val: f32 = 0.0;
    for (out) |v| if (v > max_val) {
        max_val = v;
    };
    if (max_val > 0.0) {
        const inv = 1.0 / max_val;
        for (out) |*v| v.* *= inv;
    }

    return out;
}
