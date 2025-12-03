const std = @import("std");
const time = std.time;
const print = std.debug.print;

// Records the time in microseconds
pub fn Click() i64 {
    return time.microTimestamp();
}

pub fn Lap(
    click: i64,
    memo: []const u8,
) i64 {
    const now = time.microTimestamp();
    const elapsed = now - click;
    const seconds = @divTrunc(elapsed, time.us_per_s);
    print("{s}\n", .{memo});
    print("     ⏱️ {d} seconds\n", .{seconds});
    print("         exact microseconds: {d}\n", .{elapsed});
    return elapsed;
}

test "timers" {
    print("timer test:\n", .{});
    const start = Click();
    defer _ = Lap(start, "Timer Testing");
    std.Thread.sleep(3333000);
}
