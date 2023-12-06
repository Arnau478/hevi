const std = @import("std");

const NormalizedSize = @This();

/// The actual size in the appropiate unit
magnitude: f64,
/// The unit the size is in
unit: Unit,

/// A byte multiple unit
const Unit = struct {
    order: usize,

    inline fn getName(self: Unit) []const u8 {
        return switch (self.order) {
            0 => "B",
            1 => "KiB",
            2 => "MiB",
            3 => "GiB",
            4 => "TiB",
            5 => "PiB",
            6 => "EiB",
            7 => "ZiB",
            8 => "YiB",
            else => ">>B",
        };
    }
};

/// Create a normalized size from a raw size (in bytes)
pub fn fromBytes(bytes: usize) NormalizedSize {
    var size = NormalizedSize{ .magnitude = @floatFromInt(bytes), .unit = .{ .order = 0 } };

    while (size.magnitude >= 1024) {
        size.magnitude /= 1024;
        size.unit.order += 1;
    }

    return size;
}

pub fn format(self: NormalizedSize, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    try writer.print("{d:.2} {s}", .{ self.magnitude, self.unit.getName() });
}
