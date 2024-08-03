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
