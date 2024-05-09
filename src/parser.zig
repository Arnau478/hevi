const std = @import("std");
const PaletteColor = @import("main.zig").PaletteColor;

const parsers = &.{
    @import("parsers/elf.zig"),
    @import("parsers/data.zig"),
};

pub fn getColors(allocator: std.mem.Allocator, reader: std.io.AnyReader) ![]const PaletteColor {
    const data = try reader.readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(data);

    const colors = try allocator.alloc(PaletteColor, data.len);

    inline for (parsers) |parser| {
        if (parser.matches(data)) {
            parser.getColors(colors, data);
            return colors;
        }
    }

    @panic("No parser matched");
}
