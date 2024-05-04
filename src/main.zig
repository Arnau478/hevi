const std = @import("std");
const argparse = @import("argparse.zig");
const hoptions = @import("options.zig");
const DisplayOptions = hoptions.DisplayOptions;
const NormalizedSize = @import("NormalizedSize.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const allocator = gpa.allocator();

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

fn displayLine(line: []const u8, writer: anytype, options: DisplayLineOptions) !void {
    if (options.color) {
        try writer.print("\x1b[2m|\x1b[0m ", .{});
    } else try writer.print("| ", .{});

    for (line, 0..) |byte, i| {
        if (options.color) {
            try writer.print("{s}", .{if (isPrintable(byte)) "\x1b[33m" else "\x1b[33m\x1b[2m"});
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
        for (line) |byte| {
            const printable = isPrintable(byte);

            if (options.color) {
                try writer.print("{s}", .{if (printable) "\x1b[33m" else "\x1b[2m"});
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

fn printBuffer(line: []const u8, count: usize, writer: anytype, options: DisplayOptions) !void {
    if (options.show_offset) {
        if (options.uppercase) {
            try writer.print("{X:0>8} ", .{count});
        } else try writer.print("{x:0>8} ", .{count});
    }

    try displayLine(line, writer, .{
        .color = options.color,
        .uppercase = options.uppercase,
        .show_ascii = options.show_ascii,
    });
}

fn display(reader: anytype, writer: anytype, options: DisplayOptions) !void {
    var count: usize = 0;

    var buf: [16]u8 = undefined;

    // Variables for `--skip-lines`
    var previous_buf: [16]u8 = undefined;
    var previous_line_len: ?usize = null;
    var lines_skipped: usize = 0;

    while (true) {
        const line_len = try reader.readAll(&buf);

        if (line_len == 0) {
            // If `options.skip_lines`
            if (lines_skipped != 0) {
                try writer.print("... {d} lines skipped ...\n", .{lines_skipped - 1});
                try printBuffer(previous_buf[0..previous_line_len.?], count - previous_line_len.?, writer, options);
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
                } else if (lines_skipped != 0) {
                    try writer.print("... {d} lines skipped ...\n", .{lines_skipped - 1});
                    try printBuffer(previous_buf[0..p_line_len], count - p_line_len, writer, options);

                    lines_skipped = 0;
                }
            }

            previous_buf = buf;
            previous_line_len = line_len;
        }

        try printBuffer(line, count, writer, options);

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

    try display(file.reader(), stdout.writer(), try hoptions.getOptions(parsed_args, stdout));
}
