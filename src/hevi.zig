const std = @import("std");
const NormalizedSize = @import("NormalizedSize.zig");

pub const DisplayOptions = @import("DisplayOptions.zig");

/// ANSI color
pub const TextColor = struct {
    foreground: ?BaseColor = null,
    background: ?BaseColor = null,
    dim: bool = false,
    bold: bool = false,

    pub const BaseColor = union(enum) {
        standard: Standard,
        true_color: TrueColor,

        pub const Standard = enum(u4) {
            black,
            red,
            green,
            yellow,
            blue,
            magenta,
            cyan,
            white,
            bright_black,
            bright_red,
            bright_green,
            bright_yellow,
            bright_blue,
            bright_magenta,
            bright_cyan,
            bright_white,
        };

        pub const TrueColor = struct {
            r: u8,
            g: u8,
            b: u8,
        };
    };

    pub fn ansiCode(self: TextColor, writer: anytype) !void {
        if (self.foreground) |foreground| {
            switch (foreground) {
                .standard => |standard| _ = try writer.write(switch (standard) {
                    .black => "\x1b[30m",
                    .red => "\x1b[31m",
                    .green => "\x1b[32m",
                    .yellow => "\x1b[33m",
                    .blue => "\x1b[34m",
                    .magenta => "\x1b[35m",
                    .cyan => "\x1b[36m",
                    .white => "\x1b[37m",
                    .bright_black => "\x1b[90m",
                    .bright_red => "\x1b[91m",
                    .bright_green => "\x1b[92m",
                    .bright_yellow => "\x1b[93m",
                    .bright_blue => "\x1b[94m",
                    .bright_magenta => "\x1b[95m",
                    .bright_cyan => "\x1b[96m",
                    .bright_white => "\x1b[97m",
                }),
                .true_color => |true_color| try writer.print("\x1b[38;2;{d};{d};{d}m", .{
                    true_color.r,
                    true_color.g,
                    true_color.b,
                }),
            }
        }

        if (self.background) |background| {
            switch (background) {
                .standard => |standard| _ = try writer.write(switch (standard) {
                    .black => "\x1b[40m",
                    .red => "\x1b[41m",
                    .green => "\x1b[42m",
                    .yellow => "\x1b[43m",
                    .blue => "\x1b[44m",
                    .magenta => "\x1b[45m",
                    .cyan => "\x1b[46m",
                    .white => "\x1b[47m",
                    .bright_black => "\x1b[100m",
                    .bright_red => "\x1b[101m",
                    .bright_green => "\x1b[102m",
                    .bright_yellow => "\x1b[103m",
                    .bright_blue => "\x1b[104m",
                    .bright_magenta => "\x1b[105m",
                    .bright_cyan => "\x1b[106m",
                    .bright_white => "\x1b[107m",
                }),
                .true_color => |true_color| try writer.print("\x1b[48;2;{d};{d};{d}m", .{
                    true_color.r,
                    true_color.g,
                    true_color.b,
                }),
            }
        }

        if (self.dim) _ = try writer.write("\x1b[2m");
        if (self.bold) _ = try writer.write("\x1b[1m");
    }
};

/// Generalized color, agnostic to the current color palette
pub const PaletteColor = enum {
    normal,
    normal_alt,
    normal_accent,
    c1,
    c1_alt,
    c1_accent,
    c2,
    c2_alt,
    c2_accent,
    c3,
    c3_alt,
    c3_accent,
    c4,
    c4_alt,
    c4_accent,
    c5,
    c5_alt,
    c5_accent,
};

/// A color palette, that associates `PaletteColor`s to `TextColor`s
pub const ColorPalette = std.enums.EnumFieldStruct(PaletteColor, TextColor, null);

/// The default color palette
pub const default_palette: ColorPalette = .{
    .normal = .{ .foreground = .{ .standard = .yellow } },
    .normal_alt = .{ .foreground = .{ .standard = .yellow }, .dim = true },
    .normal_accent = .{ .foreground = .{ .standard = .bright_yellow }, .bold = true },
    .c1 = .{ .foreground = .{ .standard = .red } },
    .c1_alt = .{ .foreground = .{ .standard = .red }, .dim = true },
    .c1_accent = .{ .foreground = .{ .standard = .bright_red }, .bold = true },
    .c2 = .{ .foreground = .{ .standard = .green } },
    .c2_alt = .{ .foreground = .{ .standard = .green }, .dim = true },
    .c2_accent = .{ .foreground = .{ .standard = .bright_green }, .bold = true },
    .c3 = .{ .foreground = .{ .standard = .blue } },
    .c3_alt = .{ .foreground = .{ .standard = .blue }, .dim = true },
    .c3_accent = .{ .foreground = .{ .standard = .bright_blue }, .bold = true },
    .c4 = .{ .foreground = .{ .standard = .magenta } },
    .c4_alt = .{ .foreground = .{ .standard = .magenta }, .dim = true },
    .c4_accent = .{ .foreground = .{ .standard = .bright_magenta }, .bold = true },
    .c5 = .{ .foreground = .{ .standard = .cyan } },
    .c5_alt = .{ .foreground = .{ .standard = .cyan }, .dim = true },
    .c5_accent = .{ .foreground = .{ .standard = .bright_cyan }, .bold = true },
};

pub const Parser = enum {
    elf,
    pe,
    qoi,
    data,

    pub const Meta = struct {
        description: []const u8,
    };

    fn Namespace(self: Parser) type {
        return switch (self) {
            .elf => @import("parsers/elf.zig"),
            .pe => @import("parsers/pe.zig"),
            .qoi => @import("parsers/qoi.zig"),
            .data => @import("parsers/data.zig"),
        };
    }

    pub fn meta(self: Parser) Meta {
        return switch (self) {
            inline else => |p| p.Namespace().meta,
        };
    }

    pub fn matches(self: Parser, data: []const u8) bool {
        return switch (self) {
            inline else => |p| p.Namespace().matches(data),
        };
    }

    pub fn getColors(self: Parser, colors: []PaletteColor, data: []const u8) void {
        switch (self) {
            inline else => |p| p.Namespace().getColors(colors, data),
        }
    }
};

fn getColors(allocator: std.mem.Allocator, reader: anytype, options: DisplayOptions) ![]const PaletteColor {
    const data = try reader.readAllAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(data);

    const colors = try allocator.alloc(PaletteColor, data.len);

    inline for (comptime std.enums.values(Parser)) |parser| {
        if (options.parser) |p| {
            if (parser == p) {
                if (parser.matches(data)) {
                    parser.getColors(colors, data);
                    return colors;
                } else {
                    return error.NonMatchingParser;
                }
            }
        } else if (parser.matches(data)) {
            parser.getColors(colors, data);
            return colors;
        }
    }

    @panic("No parser matched");
}

inline fn isPrintable(c: u8) bool {
    return switch (c) {
        0x20...0x7E => true,
        else => false,
    };
}

const DisplayLineOptions = struct {
    color: bool,
    uppercase: bool,
    show_ascii: bool,
    raw: bool,
};

fn displayLine(line: []const u8, colors: []const TextColor, writer: anytype, options: DisplayLineOptions) !void {
    if (!options.raw) {
        if (options.color) {
            try writer.print("\x1b[2m|\x1b[0m ", .{});
        } else try writer.print("| ", .{});
    }

    for (line, colors, 0..) |byte, color, i| {
        if (options.color) {
            try color.ansiCode(writer);
        }

        if (options.uppercase) {
            try writer.print("{X:0>2}", .{byte});
        } else try writer.print("{x:0>2}", .{byte});

        if (options.color) try writer.print("\x1b[0m", .{});

        if (i % 2 == 1) try writer.print(" ", .{});
    }

    if (line.len != 16) {
        for (0..(16 - line.len)) |_| try writer.print("  ", .{});
        for (0..std.math.divCeil(usize, 16 - line.len, 2) catch unreachable) |_| try writer.print(" ", .{});
    }

    if (!options.raw) {
        if (options.color) {
            try writer.print("\x1b[2m|\x1b[0m", .{});
        } else try writer.print("|", .{});
    }

    if (options.show_ascii) {
        try writer.print(" ", .{});
        for (line, colors) |byte, color| {
            const printable = isPrintable(byte);

            if (options.color) {
                if (printable) {
                    try color.ansiCode(writer);
                } else {
                    _ = try writer.write("\x1b[2m");
                }
            }

            try writer.print("{c}", .{if (printable) byte else '.'});

            if (options.color) try writer.print("\x1b[0m", .{});
        }

        if (line.len != 16) {
            for (0..(16 - line.len)) |_| try writer.print(" ", .{});
        }

        if (options.color) {
            try writer.print(" \x1b[2m|\x1b[0m", .{});
        } else try writer.print(" |", .{});
    }

    try writer.print("\n", .{});
}

fn printBuffer(line: []const u8, colors: []const TextColor, count: usize, writer: anytype, options: DisplayOptions) !void {
    if (options.show_offset) {
        if (options.uppercase) {
            try writer.print("{X:0>8} ", .{count});
        } else try writer.print("{x:0>8} ", .{count});
    }

    try displayLine(line, colors[count .. count + line.len], writer, .{
        .color = options.color,
        .uppercase = options.uppercase,
        .show_ascii = options.show_ascii,
        .raw = options.raw,
    });
}

fn display(reader: anytype, colors: []const TextColor, raw_writer: anytype, options: DisplayOptions) !void {
    var count: usize = 0;

    var buf: [16]u8 = undefined;

    // Variables for `--skip-lines`
    var previous_buf: [16]u8 = undefined;
    var previous_line_len: ?usize = null;
    var lines_skipped: usize = 0;

    var buf_writer = std.io.bufferedWriter(raw_writer);
    const writer = buf_writer.writer();

    while (true) {
        const line_len = try reader.readAll(&buf);

        if (line_len == 0) {
            switch (lines_skipped) {
                0 => {},
                1 => try printBuffer(previous_buf[0..previous_line_len.?], colors, count - previous_line_len.?, writer, options),
                else => {
                    try writer.print("... {d} lines skipped ...\n", .{lines_skipped - 1});
                    try printBuffer(previous_buf[0..previous_line_len.?], colors, count - previous_line_len.?, writer, options);
                },
            }
            break;
        }

        const line = buf[0..line_len];

        if (options.skip_lines) {
            if (previous_line_len) |p_line_len| {
                if (std.mem.eql(u8, line, previous_buf[0..p_line_len])) {
                    lines_skipped += 1;
                    count += line_len;
                    continue;
                }

                switch (lines_skipped) {
                    0 => {},
                    1 => {
                        try printBuffer(previous_buf[0..previous_line_len.?], colors, count - previous_line_len.?, writer, options);
                        lines_skipped = 0;
                    },
                    else => {
                        try writer.print("... {d} lines skipped ...\n", .{lines_skipped - 1});
                        try printBuffer(previous_buf[0..previous_line_len.?], colors, count - previous_line_len.?, writer, options);
                        lines_skipped = 0;
                    },
                }
            }

            previous_buf = buf;
            previous_line_len = line_len;
        }

        try printBuffer(line, colors, count, writer, options);

        count += line_len;

        try buf_writer.flush();
    }

    if (options.show_size) {
        if (count < 1024) {
            try writer.print("File size: {} bytes\n", .{count});
        } else try writer.print("File size: {} bytes ({})\n", .{ count, NormalizedSize.fromBytes(count) });
    }

    try buf_writer.flush();
}

/// Dump `data` to `writer`
pub fn dump(allocator: std.mem.Allocator, data: []const u8, writer: anytype, options: DisplayOptions) !void {
    var fbs = std.io.fixedBufferStream(data);

    const colors = try getColors(allocator, fbs.reader(), options);
    defer allocator.free(colors);

    fbs.reset();

    const text_colors = try allocator.alloc(TextColor, colors.len);
    defer allocator.free(text_colors);

    for (colors, text_colors) |color, *text_color| {
        text_color.* = switch (color) {
            inline else => |c| @field(options.palette, @tagName(c)),
        };
    }

    var new_options = options;
    if (options.raw) {
        new_options.color = false;
        new_options.show_size = false;
        new_options.show_ascii = false;
        new_options.show_offset = false;
        new_options.skip_lines = false;
    }

    try display(
        fbs.reader(),
        text_colors,
        writer,
        new_options,
    );
}

test {
    _ = std.testing.refAllDeclsRecursive(@This());
}

fn testDump(expected: []const u8, input: []const u8, options: DisplayOptions) !void {
    var out = std.ArrayList(u8).init(std.testing.allocator);
    defer out.deinit();
    try out.ensureTotalCapacity(expected.len);

    try dump(std.testing.allocator, input, out.writer(), options);

    try std.testing.expectEqualSlices(u8, expected, out.items);
}

test "basic dump" {
    try testDump(
        "| 6865 6c6c 6faa                          |\n",
        "hello\xaa",
        .{
            .color = false,
            .uppercase = false,
            .show_size = false,
            .show_ascii = false,
            .skip_lines = false,
            .show_offset = false,
        },
    );
}

test "raw dump" {
    try testDump(
        "6865 6c6c 6faa                          \n",
        "hello\xaa",
        .{
            .color = false,
            .uppercase = false,
            .show_size = false,
            .show_ascii = false,
            .skip_lines = false,
            .show_offset = false,
            .raw = true,
        },
    );
}

test "empty dump" {
    try testDump(
        "",
        "",
        .{
            .color = false,
            .uppercase = false,
            .show_size = false,
            .show_ascii = false,
            .skip_lines = false,
            .show_offset = false,
        },
    );
}
