const std = @import("std");
const hevi = @import("../hevi.zig");

pub const meta = hevi.Parser.Meta{
    .description = "PE (portable executable) files",
};

const DosHeader = packed struct(u512) {
    magic: u16,
    cblp: u16,
    cp: u16,
    crlc: u16,
    cparhdr: u16,
    minalloc: u16,
    maxalloc: u16,
    ss: u16,
    sp: u16,
    csum: u16,
    ip: u16,
    cs: u16,
    lfarlc: u16,
    ovno: u16,
    rsv_a: u64 = 0,
    oemid: u16,
    oeminfo: u16,
    rsv_b: u160 = 0,
    lfanew: u32,
};

const PeHeader = extern struct {
    signature: u32,
    file_header: std.coff.CoffHeader,
};

pub fn matches(data: []const u8) bool {
    return std.mem.startsWith(u8, data, "MZ");
}

fn setRange(colors: []hevi.PaletteColor, offset: usize, len: usize, color: hevi.PaletteColor) void {
    @memset(colors[offset .. offset + len], color);
}

pub fn getColors(colors: []hevi.PaletteColor, data: []const u8) void {
    @memset(colors, .normal_alt);

    var fbs = std.io.fixedBufferStream(data);
    const reader = fbs.reader();

    const dos_header = reader.readStruct(DosHeader) catch return;
    setRange(colors, 0, @sizeOf(DosHeader), .c1);
    setRange(colors, @offsetOf(DosHeader, "magic"), @sizeOf(u16), .c1_accent);
    setRange(colors, @offsetOf(DosHeader, "lfanew"), @sizeOf(u32), .c1_accent);

    fbs.pos = dos_header.lfanew;

    setRange(colors, fbs.pos, @sizeOf(PeHeader), .c2_accent);
    setRange(colors, fbs.pos + @offsetOf(PeHeader, "file_header"), @sizeOf(std.coff.CoffHeader), .c2);

    const pe_header = reader.readStruct(PeHeader) catch return;

    reader.skipBytes(pe_header.file_header.size_of_optional_header, .{}) catch return;

    setRange(
        colors,
        fbs.pos - pe_header.file_header.size_of_optional_header,
        pe_header.file_header.size_of_optional_header,
        .c3,
    );

    if (pe_header.file_header.size_of_optional_header > 216) {
        setRange(
            colors,
            fbs.pos - pe_header.file_header.size_of_optional_header + 216,
            pe_header.file_header.size_of_optional_header - 216,
            .c3_alt,
        );
    }

    for (0..pe_header.file_header.number_of_sections) |i| {
        const section_header = reader.readStruct(std.coff.SectionHeader) catch return;
        setRange(colors, fbs.pos - @sizeOf(std.coff.SectionHeader), @sizeOf(std.coff.SectionHeader), if (i % 2 == 0) .c4 else .c5);
        setRange(colors, fbs.pos - @sizeOf(std.coff.SectionHeader), 8, if (i % 2 == 0) .c4_accent else .c5_accent);
        _ = section_header;
    }
}
