const std = @import("std");
const builtin = @import("builtin");
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

const DisplayOptions = struct {
    color: bool,
    uppercase: bool,
    show_size: bool,
    show_offset: bool,
    show_ascii: bool,
};

fn display(reader: anytype, writer: anytype, options: DisplayOptions) !void {
    var count: usize = 0;

    var buf: [16]u8 = undefined;

    while (true) {
        const line_len = try reader.readAll(&buf);
        if (line_len == 0) break;
        const line = buf[0..line_len];

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

        count += line_len;
    }

    if (options.show_size) {
        if (count < 1024) {
            try writer.print("File size: {} bytes\n", .{count});
        } else try writer.print("File size: {} bytes ({})\n", .{ count, NormalizedSize.fromBytes(count) });
    }
}

fn openConfigFile() ?std.fs.File {
    const path: ?[]const u8 = switch (builtin.os.tag) {
        .linux => if (std.posix.getenv("XDG_CONFIG_HOME")) |xdg_config_home|
            std.fs.path.join(allocator, &.{ xdg_config_home, "hevi/config.zon" }) catch null
        else if (std.posix.getenv("HOME")) |home|
            std.fs.path.join(allocator, &.{ home, ".config/hevi/config.zon" }) catch null
        else
            null,
        else => null,
    };

    return std.fs.openFileAbsolute(path orelse return null, .{}) catch null;
}

fn getOptions(args: argparse.ParseResult, stdout: std.fs.File) !DisplayOptions {
    // Default values
    var options = DisplayOptions{
        .color = stdout.supportsAnsiEscapeCodes(),
        .uppercase = false,
        .show_size = true,
        .show_offset = true,
        .show_ascii = true,
    };

    // Config file
    if (openConfigFile()) |file| {
        defer file.close();

        const stderr = std.io.getStdErr();
        defer stderr.close();

        const source = try file.readToEndAllocOptions(allocator, std.math.maxInt(usize), null, 1, 0);
        defer allocator.free(source);

        var ast = try std.zig.Ast.parse(allocator, source, .zon);
        defer ast.deinit(allocator);

        var buf: [2]std.zig.Ast.Node.Index = undefined;
        const root = ast.fullStructInit(&buf, ast.nodes.items(.data)[0].lhs) orelse {
            try stderr.writer().print("Error: Config file does not contain a struct literal\n", .{});
            return error.InvalidConfig;
        };

        for (root.ast.fields) |field| {
            const name = ast.tokenSlice(ast.firstToken(field) - 2);
            const slice = ast.tokenSlice(ast.firstToken(field));
            const value = if (ast.tokens.get(ast.firstToken(field)).tag == .identifier and std.mem.eql(u8, slice, "true"))
                true
            else if (ast.tokens.get(ast.firstToken(field)).tag == .identifier and std.mem.eql(u8, slice, "false"))
                false
            else {
                try stderr.writer().print("Error: Expected a bool for field {s} in config file\n", .{name});
                return error.InvalidConfig;
            };
            const field_ptr = blk: {
                inline for (std.meta.fields(DisplayOptions)) |opt_field| {
                    if (std.mem.eql(u8, name, opt_field.name)) break :blk &@field(options, opt_field.name);
                }
                try stderr.writer().print("Error: Invalid field in config file: {s}\n", .{name});
                return error.InvalidConfig;
            };
            field_ptr.* = value;
        }
    }

    // Environment variables
    var envs = try std.process.getEnvMap(allocator);
    defer envs.deinit();

    if (envs.get("NO_COLOR")) |s| {
        if (!std.mem.eql(u8, s, "")) options.color = false;
    }

    // Flags
    if (args.color) |color| options.color = color;
    if (args.uppercase) |uppercase| options.uppercase = uppercase;
    if (args.show_size) |show_size| options.show_size = show_size;
    if (args.show_offset) |show_offset| options.show_offset = show_offset;
    if (args.show_ascii) |show_ascii| options.show_ascii = show_ascii;

    return options;
}

pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const parsed_args = argparse.parse(args[1..]);

    const file = try std.fs.cwd().openFile(parsed_args.filename, .{});
    defer file.close();

    const stdout = std.io.getStdOut();

    try display(file.reader(), stdout.writer(), try getOptions(parsed_args, stdout));
}
