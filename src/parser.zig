const std = @import("std");
const DisplayOptions = @import("options.zig").DisplayOptions;
const PaletteColor = @import("main.zig").PaletteColor;

pub const parsers = &.{
    @import("parsers/elf.zig"),
    @import("parsers/pe.zig"),
    @import("parsers/data.zig"),
};

pub fn getColors(allocator: std.mem.Allocator, reader: std.io.AnyReader, options: DisplayOptions) ![]const PaletteColor {
    const data = try reader.readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(data);

    const colors = try allocator.alloc(PaletteColor, data.len);

    inline for (parsers) |parser| {
        if (options.parser) |p| {
            var split = std.mem.splitAny(u8, @typeName(parser), ".");
            _ = split.first();
            if (std.mem.eql(u8, split.next().?, p.string)) {
                if (parser.matches(data)) {
                    parser.getColors(colors, data);
                    return colors;
                } else {
                    std.debug.print("Error: the specified parser doesn't match the file format!\n", .{});
                    std.process.exit(1);
                }
            }
        } else if (parser.matches(data)) {
            parser.getColors(colors, data);
            return colors;
        }
    }

    @panic("No parser matched");
}

test {
    inline for (parsers) |parser| {
        _ = parser;
    }
}
