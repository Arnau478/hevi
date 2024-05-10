const std = @import("std");
const argparse = @import("argparse.zig");
const hoptions = @import("options.zig");
const DisplayOptions = hoptions.DisplayOptions;
const NormalizedSize = @import("NormalizedSize.zig");
const parser = @import("parser.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = gpa.allocator();

pub const TextColor = struct {
    base: Base,
    dim: bool,

    const Base = enum {
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

    fn ansiCode(self: TextColor, writer: anytype) !void {
        _ = try writer.write(switch (self.base) {
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
        });

        if (self.dim) _ = try writer.write("\x1b[2m");
    }
};

pub const PaletteColor = enum {
    normal,
    normal_alt,
    c1,
    c1_alt,
    c2,
    c2_alt,
    c3,
    c3_alt,
    c4,
    c4_alt,
    c5,
    c5_alt,
};

pub const ColorPalette = std.enums.EnumFieldStruct(PaletteColor, TextColor, null);

const palette: ColorPalette = .{
    .normal = .{ .base = .yellow, .dim = false },
    .normal_alt = .{ .base = .yellow, .dim = true },
    .c1 = .{ .base = .red, .dim = false },
    .c1_alt = .{ .base = .red, .dim = true },
    .c2 = .{ .base = .green, .dim = false },
    .c2_alt = .{ .base = .green, .dim = true },
    .c3 = .{ .base = .blue, .dim = false },
    .c3_alt = .{ .base = .blue, .dim = true },
    .c4 = .{ .base = .magenta, .dim = false },
    .c4_alt = .{ .base = .magenta, .dim = true },
    .c5 = .{ .base = .cyan, .dim = false },
    .c5_alt = .{ .base = .cyan, .dim = true },
};

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
};

fn displayLine(line: []const u8, colors: []const TextColor, writer: anytype, options: DisplayLineOptions) !void {
    if (options.color) {
        try writer.print("\x1b[2m|\x1b[0m ", .{});
    } else try writer.print("| ", .{});

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

    if (options.color) {
        try writer.print("\x1b[2m|\x1b[0m", .{});
    } else try writer.print("|", .{});

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
    });
}

fn display(reader: anytype, colors: []const TextColor, writer: anytype, options: DisplayOptions) !void {
    var count: usize = 0;

    var buf: [16]u8 = undefined;

    // Variables for `--skip-lines`
    var previous_buf: [16]u8 = undefined;
    var previous_line_len: ?usize = null;
    var lines_skipped: usize = 0;

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
    }

    if (options.show_size) {
        if (count < 1024) {
            try writer.print("File size: {} bytes\n", .{count});
        } else try writer.print("File size: {} bytes ({})\n", .{ count, NormalizedSize.fromBytes(count) });
    }
}

pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const parsed_args = argparse.parse(args[1..]);

    const file = try std.fs.cwd().openFile(parsed_args.filename, .{});
    defer file.close();

    const stdout = std.io.getStdOut();

    const colors = try parser.getColors(allocator, file.reader().any());
    defer allocator.free(colors);

    try file.seekTo(0);

    const text_colors = try allocator.alloc(TextColor, colors.len);
    defer allocator.free(text_colors);

    for (colors, text_colors) |color, *text_color| {
        text_color.* = switch (color) {
            inline else => |c| @field(palette, @tagName(c)),
        };
    }

    try display(file.reader(), text_colors, stdout.writer(), try hoptions.getOptions(parsed_args, stdout));
}
