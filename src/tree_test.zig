const expect = @import("std").testing.expect;
const Node = struct {
    data: u8,
    left: ?*Node = null,
    right: ?*Node = null,
};

test "basic init" {
    var a = Node{
        .data = 1,
    };
    try expect(a.data == 1);
    try expect(a.left == null);
    try expect(a.right == null);

    //anonymous structs if the type is unknown
    const b: Node = .{
        .data = 2,
        .left = &a,
        .right = null,
    };

    try expect(b.data == 2);
    //we'll have to unwrap the optional poiinter with .?, equivalent to "(b.left or else unreachable)"
    try expect(b.left.? == &a);
    try expect(a.right == null);
}

