const std = @import("std");
const ToyNode = struct {
    toy_mask: [5]u64,
    other_nodes: std.AutoHashMap(u32, *ToyNode),
    // const init: ToyNode = .{ .toy_mask = .{0} ** 5, .other_nodes = .empty };
    fn init(allocator: std.mem.Allocator) ToyNode {
        return ToyNode{
            .toy_mask = .{0} ** 5,
            .other_nodes = std.AutoHashMap(u32, *ToyNode).init(allocator),
        };
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var node = ToyNode.init(allocator);
    defer node.other_nodes.deinit();
    node.toy_mask[1] = 1;
    const not_there = node.other_nodes.get(6);
    try node.other_nodes.put(1, &node);
    const there = node.other_nodes.get(1);
    std.debug.print("mask array: {any}\n", .{node.toy_mask});
    std.debug.print("not there: {?}\n", .{not_there});
    std.debug.print("there: {?}\n", .{there});
    return;
}
