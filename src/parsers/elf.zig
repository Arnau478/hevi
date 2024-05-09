const std = @import("std");
const PaletteColor = @import("../main.zig").PaletteColor;

pub fn matches(data: []const u8) bool {
    return std.mem.startsWith(u8, data, std.elf.MAGIC);
}

pub fn getColors(colors: []PaletteColor, data: []const u8) void {
    @memset(colors, .normal_alt);

    var fbs = std.io.fixedBufferStream(data);
    const reader = fbs.reader();
    _ = reader;

    switch (data[std.elf.EI_CLASS]) {
        std.elf.ELFCLASS64 => {
            for (colors[0..@sizeOf(std.elf.Elf64_Ehdr)]) |*c| {
                c.* = .c1;
            }
        },
        std.elf.ELFCLASS32 => {
            for (colors[0..@sizeOf(std.elf.Elf32_Ehdr)]) |*c| {
                c.* = .c1;
            }
        },
        else => return,
    }
}
