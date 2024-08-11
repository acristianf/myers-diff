const std = @import("std");

const Point = struct {
    x: isize,
    y: isize,

    const Self = @This();

    pub fn zero() Point {
        return .{
            .x = 0,
            .y = 0,
        };
    }

    pub fn inverted(self: *Self) Point {
        return .{ .x = self.y, .y = self.x };
    }
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

fn midpoint(comptime T: type, a: []const T, b: []const T, scratch1: []usize, scratch2: []usize, offset_point: Point) !?[2]Point {
    if (a.len * b.len == 0) return null;
    const max = a.len + b.len;
    const max_diagonals = 2 * (max) + 1;
    const i_max: isize = @intCast(max);

    @memset(scratch1[0..max_diagonals], 0);
    @memset(scratch2[0..max_diagonals], 0);

    var v1 = scratch1[0..max_diagonals];
    var v2 = scratch2[0..max_diagonals];

    const alen: isize = @intCast(a.len);
    const blen: isize = @intCast(b.len);

    var overlap: [2]Point = undefined;

    var k: isize = 0;
    var c: isize = 0;
    const delta: isize = alen - blen;
    const even: bool = @rem(delta, 2) == 0;
    var px: isize = 0;
    var py: isize = 0;
    outer: for (0..max + 1) |u| {
        const d: isize = @intCast(u);

        k = -d;
        while (k <= d) : (k += 2) {
            var x: isize = 0;
            const real_k: usize = @intCast(k + i_max);
            if (k == -d or k != d and v1[real_k - 1] < v1[real_k + 1]) {
                x = @intCast(v1[real_k + 1]);
            } else {
                x = @intCast(v1[real_k - 1] + 1);
            }
            var y: isize = x - k;

            px = @intCast(x);
            py = @intCast(y);

            while (x < a.len and y < b.len and try match(T, a[@intCast(x)], b[@intCast(y)])) {
                x += 1;
                y += 1;
            }

            v1[real_k] = @intCast(x);

            // This case changes
            const r_c: usize = @intCast(@as(isize, @intCast(real_k)) - delta);
            if (!even and k >= -(d - 1) and k <= d - 1 and v1[real_k] > alen - @as(isize, @intCast(v2[r_c]))) {
                overlap[0] = .{ .x = px, .y = py };
                overlap[1] = .{ .x = @intCast(x), .y = @intCast(y) };
                break :outer;
            }
        }

        c = -d;
        while (c <= d) : (c += 2) {
            var x: isize = 0;
            const real_c: usize = @intCast(c + i_max);
            if (c == -d or c != d and v2[real_c - 1] < v2[real_c + 1]) {
                x = @intCast(v2[real_c + 1] + 1);
            } else {
                x = @intCast(v2[real_c - 1]);
            }
            x = alen - x;
            var y: isize = x - c - delta;

            while (x >= 0 and y >= 0 and try match(T, a[@intCast(x)], b[@intCast(y)])) {
                x -= 1;
                y -= 1;
            }

            v2[real_c] = @intCast(alen - x);

            const real_k: usize = @intCast(@as(isize, @intCast(real_c)) + delta);
            if (even and c >= -d and c <= d and v1[real_k] + v2[real_c] > a.len) {
                std.debug.print("{d} {d}\n", .{ x, y });
                y = @intCast(@abs(y));
                overlap[0] = .{ .x = px, .y = py };
                overlap[1] = .{ .x = alen - x, .y = blen - y };
                break :outer;
            }
        }
    }

    var real_overlap = overlap;

    real_overlap[0].x += offset_point.x;
    real_overlap[0].y += offset_point.y;
    real_overlap[1].x += offset_point.x;
    real_overlap[1].y += offset_point.y;

    return real_overlap;
}

pub fn distanceBackwards(comptime T: type, a: []const T, b: []const T, scratch2: []usize) !usize {
    const max = a.len + b.len;
    const max_diagonals = 2 * (max) + 1;
    const i_max: isize = @intCast(max);

    @memset(scratch2[0..max_diagonals], 0);

    var v2 = scratch2[0..max_diagonals];

    const alen: isize = @intCast(a.len);

    var c: isize = 0;
    const delta: isize = @intCast(a.len - b.len);
    var len: usize = 0;
    outer: for (0..max + 1) |u| {
        const d: isize = @intCast(u);
        c = -d;
        while (c <= d) : (c += 2) {
            var x: isize = 0;
            const real_c: usize = @intCast(c + i_max);
            if (c == -d or c != d and v2[real_c - 1] < v2[real_c + 1]) {
                x = @intCast(v2[real_c + 1] + 1);
            } else {
                x = @intCast(v2[real_c - 1]);
            }
            x = alen - x;
            var y: isize = x - c - delta;

            while (x >= 0 and y >= 0 and try match(T, a[@intCast(x)], b[@intCast(y)])) {
                x -= 1;
                y -= 1;
            }

            v2[real_c] = @intCast(alen - x);

            if (x < 0 and y < 0) {
                len = u;
                break :outer;
            }
        }
    }
    return len;
}

/// Returns minimal edit script using myers diff
pub fn diff(comptime T: type, a: []const T, b: []const T, scratch1: []usize, scratch2: []usize, offset_point: Point) !void {
    const snake_opt: ?[2]Point = try midpoint(T, a, b, scratch1, scratch2, offset_point); // [Point, Point]

    const snake: [2]Point = snake_opt orelse return;

    const relative_snake = [2]Point{ .{
        .x = snake[0].x - offset_point.x,
        .y = snake[0].y - offset_point.y,
    }, .{
        .x = snake[1].x - offset_point.x,
        .y = snake[1].y - offset_point.y,
    } };

    std.debug.print("start={any}, end={any}\n", .{ snake[0], snake[1] });
    // std.debug.print("r_s={any}, r_e={any}\n", .{ relative_snake[0], relative_snake[1] });
    std.debug.print("{d}, {d}\n", .{ a.len, b.len });
    std.debug.print("\n", .{});

    if (snake[0].x > 0 and snake[0].y > 0) {
        try diff(T, a[0..@intCast(relative_snake[0].x)], b[0..@intCast(relative_snake[0].y)], scratch1, scratch2, Point.zero());
    }

    if ((@as(isize, @intCast(a.len)) - relative_snake[1].x) > 0 and (@as(isize, @intCast(b.len)) - relative_snake[1].y) > 0) {
        try diff(T, a[@intCast(relative_snake[1].x)..a.len], b[@intCast(relative_snake[1].y)..b.len], scratch1, scratch2, snake[1]);
    }
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

// test "distance" {
//     const a = "ABCABBA";
//     const b = "CBABAC";
//     var scratch: [128]usize = undefined;
//     try std.testing.expect(try distance(u8, a, b, &scratch) == 5);
// }
//
// test "distanceBackwards" {
//     const a = "ABCABBA";
//     const b = "CBABAC";
//     var scratch: [128]usize = undefined;
//     try std.testing.expect(try distanceBackwards(u8, a, b, &scratch) == 5);
// }
//
// test "midpoint" {
//     const a = "ABCABBA";
//     const b = "CBABAC";
//     var scratch1: [128]usize = undefined;
//     var scratch2: [128]usize = undefined;
//     _ = try midpoint(u8, a, b, &scratch1, &scratch2, Point.zero());
// }

test "diff" {
    const a = "AAB";
    const b = "CCB";
    var scratch1: [128]usize = undefined;
    var scratch2: [128]usize = undefined;
    _ = try diff(u8, a, b, &scratch1, &scratch2, Point.zero());
}
