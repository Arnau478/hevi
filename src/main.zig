const std = @import("std");
const argparse = @import("argparse.zig");
const NormalizedSize = @import("NormalizedSize.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

inline fn isPrintable(c: u8) bool {
    return switch (c) {
        0x20...0x7E => true,
        else => false,
    };
}

const DisplayLineOptions = struct {
    color: bool,
    uppercase: bool,
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
        try writer.print("\x1b[2m|\x1b[0m ", .{});
    } else try writer.print("| ", .{});

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
        try writer.print(" \x1b[2m|\x1b[0m\n", .{});
    } else try writer.print(" |\n", .{});
}

const DisplayOptions = struct {
    color: bool,
    uppercase: bool,
    show_size: bool,
};

fn display(reader: anytype, writer: anytype, options: DisplayOptions) !void {
    var count: usize = 0;

    var buf: [16]u8 = undefined;

    while (true) {
        const line_len = try reader.readAll(&buf);
        if (line_len == 0) break;
        const line = buf[0..line_len];

        if (options.uppercase) {
            try writer.print("{X:0>8} ", .{count});
        } else try writer.print("{x:0>8} ", .{count});

        try displayLine(line, writer, .{
            .color = options.color,
            .uppercase = options.uppercase,
        });

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

    try display(file.reader(), stdout.writer(), .{
        .color = parsed_args.color orelse stdout.supportsAnsiEscapeCodes(),
        .uppercase = parsed_args.uppercase orelse false,
        .show_size = parsed_args.show_size orelse true,
    });
}
