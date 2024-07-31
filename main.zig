const std = @import("std");

const Point = struct {
    x: i64,
    y: i64,
};

/// Written to study Myers diff algorithm
///
/// By difference we mean the number of changes and the actions needed to
/// edit one file/string to convert, for example, A into B.
///
/// In the case of Myers, we are trying to find the smallest possible number of
/// changes to produce change A into B.
pub fn diff(allocator: std.mem.Allocator, comptime T: type, a: []const T, b: []const T) ![]Point {
    const max: i64 = @intCast(a.len + b.len);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const aa = arena.allocator();

    var v = try aa.alloc(i64, @intCast(2 * max + 1));
    @memset(v, 0);

    var trace = std.ArrayList([]i64).init(aa);
    defer trace.deinit();

    var k: i64 = 0;
    outer: for (0..@intCast(max + 1)) |u| {
        if (u != 0) {
            const clone = try aa.dupe(i64, v);
            try trace.append(clone);
        }
        const d: i64 = @intCast(u);
        k = -d;
        while (k <= d) : (k += 2) {
            var x: i64 = 0;
            var y: i64 = 0;
            const real_k: usize = @intCast(k + max);
            if (k == -d or k != d and v[real_k - 1] < v[real_k + 1]) {
                x = v[real_k + 1];
            } else {
                x = v[real_k - 1] + 1;
            }
            y = x - k;

            // TODO: Allow [][]u8
            while (x < a.len and y < b.len and a[@intCast(x)] == b[@intCast(y)]) {
                x += 1;
                y += 1;
            }

            v[real_k] = x;

            if (x >= a.len and y >= b.len) {
                break :outer;
            }
        }
    }

    const clone = try aa.dupe(i64, v);
    try trace.append(clone);

    var d: i64 = @intCast(trace.items.len - 1);

    var points = try aa.alloc(Point, @intCast(max));
    defer aa.free(points);

    var plen: usize = 0;
    while (d >= 0) : (d -= 1) {
        const node = trace.items[@intCast(d)];
        var x = node[@intCast(k + max)];
        var y = x - k;

        points[plen] = .{ .x = x, .y = y };
        plen += 1;

        if (k == -d or k != d and v[@intCast(k + max - 1)] < v[@intCast(k + max + 1)]) {
            k = k + 1;
        } else {
            k = k - 1;
        }

        const prev_x = node[@intCast(k + max)];
        const prev_y = prev_x - k;

        while (x > prev_x and y > prev_y) {
            x -= 1;
            y -= 1;
            points[plen] = .{ .x = x, .y = y };
            plen += 1;
        }
    }

    return try allocator.dupe(Point, points[0..plen]);
}

fn visualizeDiff(
    comptime T: type,
    trace: []Point,
    a: []const T,
    b: []const T,
) void {
    var last_point: Point = .{ .x = -1, .y = -1 };
    var i: i64 = @intCast(trace.len - 2);
    while (i >= 0) : (i -= 1) {
        const idx: usize = @intCast(i);
        const case = (trace[idx].x - last_point.x) - (trace[idx].y - last_point.y);
        last_point = trace[idx];

        const a_idx: usize = @intCast(@max(trace[idx].x - 1, 0));
        const b_idx: usize = @intCast(@max(trace[idx].y - 1, 0));

        switch (case) {
            0 => print(T, "{c}\n", .{a[a_idx]}),
            1 => print(T, "-{c}\n", .{a[a_idx]}),
            -1 => print(T, "+{c}\n", .{b[b_idx]}),
            else => unreachable,
        }
    }
}

// TODO: Handle more types
fn print(comptime T: type, comptime fmt: []const u8, args: anytype) void {
    const typeinfo = @typeInfo(T);
    switch (typeinfo) {
        .Int => {
            if (typeinfo.Int.bits == 8) {
                std.log.info(fmt, args);
            } else {
                std.log.info(fmt, args);
            }
        },
        else => {
            std.log.info("{any}\n", args);
        },
    }
}

test "[]const u8 diff" {
    const a = "ABCABBA";
    const b = "CBABAC";
    const trace = try diff(std.testing.allocator, u8, a, b);
    defer std.testing.allocator.free(trace);
    try std.testing.expect(trace.len == 10);
    try std.testing.expectEqual(Point{ .x = 7, .y = 6 }, trace[0]);
    try std.testing.expectEqual(Point{ .x = 0, .y = 0 }, trace[9]);
}

// test "[]const []const u8 diff" {
//     const a = [_][]const u8{ "this is the first line", "this is the second line" };
//     const b = [_][]const u8{ "this is the modified first line", "this is the second line", "this is an added third line" };
//     const trace = try diff(std.testing.allocator, []const u8, &a, &b);
//     defer std.testing.allocator.free(trace);
//     visualizeDiff([]u8, trace, a, b);
// }
