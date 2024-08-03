const std = @import("std");

const Point = struct {
    x: i64,
    y: i64,
};

const Operation = enum(u8) {
    ADDED = '+',
    DELETED = '-',
    EQUAL = ' ',
};

pub fn match(comptime T: type, a: T, b: T) !bool {
    const tinfo = @typeInfo(T);
    switch (tinfo) {
        .Int => return a == b,
        .Pointer => return std.mem.eql(@TypeOf(a[0]), a, b),
        else => return error.NotImplemented,
    }
}

/// Returns minimal distance edit script using myers diff
pub fn distance(comptime T: type, a: []const T, b: []const T, scratch: []usize) !usize {
    const max = a.len + b.len;
    std.debug.assert(2 * max + 1 <= scratch.len);
    @memset(scratch, 0);

    var k: isize = 0;
    var mles: usize = 0;
    outer: for (0..max + 1) |u| {
        const d: isize = @intCast(u);
        k = -d;
        while (k <= d) : (k += 2) {
            var x: isize = 0;
            const shifted_k: usize = @intCast(k + @as(isize, @intCast(max)));
            if (k == -d or k != d and scratch[shifted_k - 1] < scratch[shifted_k + 1]) {
                x = @intCast(scratch[shifted_k + 1]);
            } else {
                x = @intCast(scratch[shifted_k - 1] + 1);
            }
            var y: isize = x - k;

            while (x < a.len and y < b.len and try match(T, a[@intCast(x)], b[@intCast(y)])) {
                x += 1;
                y += 1;
            }

            scratch[shifted_k] = @intCast(x);

            if (x >= a.len and y >= b.len) {
                mles = u;
                break :outer;
            }
        }
    }
    return mles;
}

///  Written to study Myers diff algorithm
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

            while (x < a.len and y < b.len and try match(T, a[x], b[y])) {
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
            0 => print(T, Operation.EQUAL, .{a[a_idx]}),
            1 => print(T, Operation.DELETED, .{a[a_idx]}),
            -1 => print(T, Operation.ADDED, .{b[b_idx]}),
            else => unreachable,
        }
    }
}

// TODO: Handle more types
fn print(comptime T: type, op: Operation, args: anytype) void {
    const typeinfo = @typeInfo(T);
    std.debug.print("{c}", .{@intFromEnum(op)});
    switch (typeinfo) {
        .Int => {
            if (typeinfo.Int.bits == 8) {
                std.log.info("{c}\n", args);
            } else {
                std.log.info("{d}\n", args);
            }
        },
        .Pointer => {
            if (typeinfo.Pointer.child == u8) {
                std.debug.print("{s}\n", args);
            }
        },
        else => {
            std.debug.print("{any}\n", args);
        },
    }
}

test "distance" {
    const a = "ABCABBA";
    const b = "CBABAC";
    var out_buf: [128]usize = undefined;
    try std.testing.expect(try distance(u8, a, b, &out_buf) == 5);
}

// test "[]const u8 diff" {
//     const a = "ABCABBA";
//     const b = "CBABAC";
//     const trace = try diff(std.testing.allocator, u8, a, b);
//     defer std.testing.allocator.free(trace);
//     try std.testing.expect(trace.len == 10);
//     try std.testing.expectEqual(Point{ .x = 7, .y = 6 }, trace[0]);
//     try std.testing.expectEqual(Point{ .x = 0, .y = 0 }, trace[9]);
// }
//
// test "[]const []const u8 diff" {
//     const a = [_][]const u8{ "this is the first line", "this is the second line" };
//     const b = [_][]const u8{ "this is the modified first line", "this is the second line", "this is an added third line" };
//     const trace = try diff(std.testing.allocator, []const u8, &a, &b);
//     std.debug.print("{d}", .{trace.len});
//     std.debug.print("({d}, {d})\n", .{ trace[0].x, trace[0].y });
//     defer std.testing.allocator.free(trace);
// }
