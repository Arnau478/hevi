const builtin = @import("builtin");
const std = @import("std");
const argparse = @import("argparse.zig");

const allocator = @import("main.zig").allocator;

pub const DisplayOptions = struct {
    color: bool,
    uppercase: bool,
    show_size: bool,
    show_offset: bool,
    show_ascii: bool,
    skip_lines: bool,
    parser: ?[]const u8,
};

fn openConfigFile(env_map: std.process.EnvMap) ?std.fs.File {
    const path: ?[]const u8 = switch (builtin.os.tag) {
        .linux, .macos, .freebsd, .openbsd, .netbsd => if (env_map.get("XDG_CONFIG_HOME")) |xdg_config_home|
            std.fs.path.join(allocator, &.{ xdg_config_home, "hevi/config.zon" }) catch null
        else if (env_map.get("HOME")) |home|
            std.fs.path.join(allocator, &.{ home, ".config/hevi/config.zon" }) catch null
        else
            null,
        .windows => if (env_map.get("APPDATA")) |appdata|
            std.fs.path.join(allocator, &.{ appdata, "hevi/config.zon" }) catch null
        else
            null,
        else => null,
    };

    return std.fs.openFileAbsolute(path orelse return null, .{}) catch null;
}

pub fn getOptions(args: argparse.ParseResult, stdout: std.fs.File) !DisplayOptions {
    var envs = try std.process.getEnvMap(allocator);
    defer envs.deinit();

    // Default values
    var options = DisplayOptions{
        .color = stdout.supportsAnsiEscapeCodes(),
        .uppercase = false,
        .show_size = true,
        .show_offset = true,
        .show_ascii = true,
        .skip_lines = true,
        .parser = null,
    };

    // Config file
    if (openConfigFile(envs)) |file| {
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
                    if (std.mem.eql(u8, name, opt_field.name) and opt_field.type == bool) break :blk &@field(options, opt_field.name);
                }
                try stderr.writer().print("Error: Invalid field in config file: {s}\n", .{name});
                return error.InvalidConfig;
            };
            field_ptr.* = value;
        }
    }

    // Environment variables
    if (envs.get("NO_COLOR")) |s| {
        if (!std.mem.eql(u8, s, "")) options.color = false;
    }

    // Flags
    if (args.color) |color| options.color = color;
    if (args.uppercase) |uppercase| options.uppercase = uppercase;
    if (args.show_size) |show_size| options.show_size = show_size;
    if (args.show_offset) |show_offset| options.show_offset = show_offset;
    if (args.show_ascii) |show_ascii| options.show_ascii = show_ascii;
    if (args.skip_lines) |skip_lines| options.skip_lines = skip_lines;
    if (args.parser) |parser| options.parser = parser;

    return options;
}
