const std = @import("std");
const hevi = @import("../hevi.zig");

pub fn matches(_: []const u8) bool {
    return true;
}

pub fn getColors(colors: []hevi.PaletteColor, data: []const u8) void {
    for (data, colors) |byte, *color| {
        color.* = switch (byte) {
            0x20...0x7E => .normal,
            else => .normal_alt,
        };
    }
}
