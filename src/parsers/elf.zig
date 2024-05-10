const std = @import("std");
const PaletteColor = @import("../main.zig").PaletteColor;

pub fn matches(data: []const u8) bool {
    return std.mem.startsWith(u8, data, std.elf.MAGIC);
}

fn setRange(colors: []PaletteColor, offset: usize, len: usize, color: PaletteColor) void {
    @memset(colors[offset .. offset + len], color);
}

pub fn getColors(colors: []PaletteColor, data: []const u8) void {
    @memset(colors, .normal_alt);

    var fbs = std.io.fixedBufferStream(data);
    const reader = fbs.reader();

    switch (data[std.elf.EI_CLASS]) {
        std.elf.ELFCLASS64 => {
            setRange(colors, 0, @sizeOf(std.elf.Elf64_Ehdr), .c1);
            const ehdr = reader.readStruct(std.elf.Elf64_Ehdr) catch return;

            fbs.pos = ehdr.e_phoff;
            for (0..ehdr.e_phnum) |i| {
                setRange(colors, fbs.pos, @sizeOf(std.elf.Elf64_Phdr), if (i % 2 == 0) .c2 else .c3);
                const phdr = reader.readStruct(std.elf.Elf64_Phdr) catch return;
                if (phdr.p_offset != 0 and phdr.p_type != std.elf.PT_PHDR) setRange(colors, phdr.p_offset, phdr.p_filesz, if (i % 2 == 0) .c2_alt else .c3_alt);
            }

            fbs.pos = ehdr.e_shoff;
            for (0..ehdr.e_shnum) |i| {
                setRange(colors, fbs.pos, @sizeOf(std.elf.Elf64_Shdr), if (i % 2 == 0) .c4 else .c5);
                const shdr = reader.readStruct(std.elf.Elf64_Shdr) catch return;
                if (shdr.sh_offset != 0 and shdr.sh_type != std.elf.SHT_NOBITS and shdr.sh_type != std.elf.SHT_NULL) {
                    setRange(colors, shdr.sh_offset, shdr.sh_size, if (i % 2 == 0) .c4_alt else .c5_alt);
                }
            }
        },
        std.elf.ELFCLASS32 => {
            setRange(colors, 0, @sizeOf(std.elf.Elf32_Ehdr), .c1);
            const ehdr = reader.readStruct(std.elf.Elf32_Ehdr) catch return;

            fbs.pos = ehdr.e_phoff;
            for (0..ehdr.e_phnum) |i| {
                setRange(colors, fbs.pos, @sizeOf(std.elf.Elf32_Phdr), if (i % 2 == 0) .c2 else .c3);
                const phdr = reader.readStruct(std.elf.Elf32_Phdr) catch return;
                if (phdr.p_offset != 0 and phdr.p_type != std.elf.PT_PHDR) setRange(colors, phdr.p_offset, phdr.p_filesz, if (i % 2 == 0) .c2_alt else .c3_alt);
            }

            fbs.pos = ehdr.e_shoff;
            for (0..ehdr.e_shnum) |i| {
                setRange(colors, fbs.pos, @sizeOf(std.elf.Elf32_Shdr), if (i % 2 == 0) .c4 else .c5);
                const shdr = reader.readStruct(std.elf.Elf32_Shdr) catch return;
                if (shdr.sh_offset != 0 and shdr.sh_type != std.elf.SHT_NOBITS and shdr.sh_type != std.elf.SHT_NULL) {
                    setRange(colors, shdr.sh_offset, shdr.sh_size, if (i % 2 == 0) .c4_alt else .c5_alt);
                }
            }
        },
        else => return,
    }
}
