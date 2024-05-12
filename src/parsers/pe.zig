const std = @import("std");
const PaletteColor = @import("../main.zig").PaletteColor;

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

fn setRange(colors: []PaletteColor, offset: usize, len: usize, color: PaletteColor) void {
    @memset(colors[offset .. offset + len], color);
}

pub fn getColors(colors: []PaletteColor, data: []const u8) void {
    @memset(colors, .normal_alt);

    var fbs = std.io.fixedBufferStream(data);
    const reader = fbs.reader();

    const dos_header = reader.readStruct(DosHeader) catch return;
    setRange(colors, 0, @sizeOf(DosHeader), .c1);

    fbs.pos = dos_header.lfanew;

    setRange(colors, fbs.pos, @sizeOf(PeHeader), .c2_alt);
    setRange(colors, fbs.pos + @offsetOf(PeHeader, "file_header"), @sizeOf(std.coff.CoffHeader), .c2);

    const pe_header = reader.readStruct(PeHeader) catch return;
    _ = pe_header;

    setRange(colors, 0, 64, .c1);
}
