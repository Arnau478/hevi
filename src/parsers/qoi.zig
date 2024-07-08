const std = @import("std");
const hevi = @import("../hevi.zig");

pub const meta = hevi.Parser.Meta{
    .description = "QOI (Quite OK Image)",
};

const QoiHeader = packed struct {
    magic: u32,
    width: u32,
    height: u32,
    channels: u8,
    colorspace: u8,
};

pub fn matches(data: []const u8) bool {
    return std.mem.startsWith(u8, data, "qoif");
}

fn setRange(colors: []hevi.PaletteColor, offset: usize, len: usize, color: hevi.PaletteColor) void {
    @memset(colors[offset .. offset + len], color);
}

pub fn getColors(colors: []hevi.PaletteColor, _: []const u8) void {
    @memset(colors, .normal_alt);

    setRange(colors, 0, @sizeOf(QoiHeader), .c1);
    setRange(colors, @offsetOf(QoiHeader, "magic"), @sizeOf(u32), .c1_accent);
}
