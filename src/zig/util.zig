const std = @import("std");
const random = std.crypto.random;
const eql = std.mem.eql;
const ArrayList = std.array_list.Managed;

//entirely random uuid
pub fn UUIDv4() [36]u8 {
    var result: [36]u8 = undefined;
    const hex_chars = "0123456789abcdef";

    var i: usize = 0;
    while (i < 36) {
        if ((i == 8) or (i == 13) or (i == 18) or (i == 23)) {
            result[i] = '-';
            i += 1;
        } else {
            result[i] = hex_chars[random.int(u4)];
            i += 1;
        }
    }
    return result;
}

test "UUID" {
    std.debug.print("🎲 ten, totally random UUIDs (UUID Version 4):\n", .{});
    for (0..10) |_| {
        std.debug.print("      🪪 {s}\n", .{UUIDv4()});
    }
}

// mirror's python's zip function
pub fn zipPairs(
    comptime T1: type,
    comptime T2: type,
    a: []const T1,
    b: []const T2,
    alloc: std.mem.Allocator,
) !std.array_list.Managed(struct { T1, T2 }) {
    var res = std.array_list.Managed(struct { T1, T2 }).init(alloc);
    const len = @min(a.len, b.len);
    for (0..len) |i| {
        try res.append(.{ a[i], b[i] });
    }
    return res;
}

test "zip pairs" {
    std.debug.print("👯 zipping pairs test\n", .{});
    const a = [_][*:0]const u8{ "and", "band", "canned", "d", "e" };
    const b = [_]usize{ 2, 4, 6, 8, 10, 11 };
    //NOTE: 11 or anything above the shared min is discarded
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();

    const res = try zipPairs(
        [*:0]const u8,
        usize,
        &a,
        &b,
        gpa_alloc,
    );
    defer res.deinit();
    //ROBOT: claude built loop
    for (res.items) |pair| {
        std.debug.print("result: {s}, {d}\n", .{ pair[0], pair[1] });
    }
}

pub fn reverseSlice(
    comptime T: type,
    input_slice: []const T,
    alloc: std.mem.Allocator,
) !std.array_list.Managed(T) {
    var res = std.array_list.Managed(T).init(alloc);
    var i = input_slice.len;
    while (i > 0) {
        i -= 1;
        try res.append(input_slice[i]);
    }
    return res;
}

test "reversing slices" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();
    const nums = [_]usize{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    const rev_nums = try reverseSlice(usize, &nums, gpa_alloc);
    defer rev_nums.deinit();
    std.debug.print("◀️ Reversed nums: {any}\n", .{rev_nums.items});
}

pub fn numDigitsShort(n: u16) u8 { //LLM: heavily inspired by chatGPT code
    if (n == 0) return 1;
    var count: u8 = 0;
    var value = n;
    while (value > 0) : (value /= 10) {
        count += 1;
    }
    return count;
}

const expect = std.testing.expect;
test "num digits" {
    try expect(numDigitsShort(100) == 3);
    try expect(numDigitsShort(1) == 1);
    try expect(numDigitsShort(65535) == 5);
}

pub fn charIsInt(chars: []const u8) bool {
    //as per: https://upload.wikimedia.org/wikipedia/commons/1/1b/ASCII-Table-wide.svg
    for (chars) |c| {
        if ((c < 48) or (c > 57)) {
            return false;
        }
    }
    return true;
}

test "strings" {
    std.debug.print("🎻 testing strings\n", .{});
    std.debug.print("module level\n", .{});
    try std.testing.expect(charIsInt("42"));
    try std.testing.expect(charIsInt("0"));
    try std.testing.expect(!charIsInt("ham"));
}
