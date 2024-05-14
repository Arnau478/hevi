const builtin = @import("builtin");
const std = @import("std");
const hevi = @import("hevi");
const argparse = @import("argparse.zig");

const ConfigFileFormats = enum {
    json,

    fn Namespace(self: ConfigFileFormats) type {
        return switch (self) {
            .json => @import("configs/json.zig"),
        };
    }

    pub fn getConfigPath(self: @This()) []const u8 {
        return switch (self) {
            inline else => |f| f.Namespace().getConfigPath(),
        };
    }

    pub fn parse(self: @This(), options: *hevi.DisplayOptions, allocator: std.mem.Allocator, file: std.fs.File) !void {
        return switch (self) {
            inline else => |f| f.Namespace().parse(options, allocator, file),
        };
    }
};

fn openConfigFile(allocator: std.mem.Allocator, env_map: std.process.EnvMap, config_path: []const u8) ?std.meta.Tuple(&.{ std.fs.File, []const u8 }) {
    const path: ?[]const u8 = switch (builtin.os.tag) {
        .linux, .macos, .freebsd, .openbsd, .netbsd => if (env_map.get("XDG_CONFIG_HOME")) |xdg_config_home|
            std.fs.path.join(allocator, &.{ xdg_config_home, "hevi/", config_path }) catch null
        else if (env_map.get("HOME")) |home|
            std.fs.path.join(allocator, &.{ home, ".config/hevi/", config_path }) catch null
        else
            null,
        .windows => if (env_map.get("APPDATA")) |appdata|
            std.fs.path.join(allocator, &.{ appdata, "hevi/", config_path }) catch null
        else
            null,
        else => null,
    };

    return .{ std.fs.openFileAbsolute(path orelse return null, .{}) catch {
        allocator.free(path.?);
        return null;
    }, path orelse return null };
}

pub fn getOptions(allocator: std.mem.Allocator, args: argparse.ParseResult, stdout: std.fs.File) !hevi.DisplayOptions {
    var envs = try std.process.getEnvMap(allocator);
    defer envs.deinit();

    // Default values
    var options = hevi.DisplayOptions{
        .color = stdout.supportsAnsiEscapeCodes(),
        .uppercase = false,
        .show_size = true,
        .show_offset = true,
        .show_ascii = true,
        .skip_lines = true,
    };

    // Config file
    for (comptime std.enums.values(ConfigFileFormats)) |format| {
        if (openConfigFile(allocator, envs, format.getConfigPath())) |tuple| {
            defer {
                tuple[0].close();
                allocator.free(tuple[1]);
            }

            try format.parse(&options, allocator, tuple[0]);
        } else {
            continue;
        }
        break;
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
