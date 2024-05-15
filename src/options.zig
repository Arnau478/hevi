const builtin = @import("builtin");
const std = @import("std");
const hevi = @import("hevi");
const argparse = @import("argparse.zig");

fn openConfigFile(allocator: std.mem.Allocator, env_map: std.process.EnvMap) ?std.meta.Tuple(&.{ std.fs.File, []const u8 }) {
    const path: ?[]const u8 = switch (builtin.os.tag) {
        .linux, .macos, .freebsd, .openbsd, .netbsd => if (env_map.get("XDG_CONFIG_HOME")) |xdg_config_home|
            std.fs.path.join(allocator, &.{ xdg_config_home, "hevi/config.json" }) catch null
        else if (env_map.get("HOME")) |home|
            std.fs.path.join(allocator, &.{ home, ".config/hevi/config.json" }) catch null
        else
            null,
        .windows => if (env_map.get("APPDATA")) |appdata|
            std.fs.path.join(allocator, &.{ appdata, "hevi/config.json" }) catch null
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
    if (openConfigFile(allocator, envs)) |tuple| {
        defer {
            tuple[0].close();
            allocator.free(tuple[1]);
        }

        const source = try tuple[0].readToEndAllocOptions(allocator, std.math.maxInt(usize), null, 1, 0);
        defer allocator.free(source);

        const OptionalDisplayOptions = struct {
            color: ?bool = null,
            uppercase: ?bool = null,
            show_size: ?bool = null,
            show_offset: ?bool = null,
            show_ascii: ?bool = null,
            skip_lines: ?bool = null,
            parser: ?hevi.Parser = null,
            palette: ?hevi.ColorPalette = null,

            comptime {
                std.debug.assert(std.meta.fields(@This()).len == std.meta.fields(hevi.DisplayOptions).len);
            }
        };

        const parsed = std.json.parseFromSlice(OptionalDisplayOptions, allocator, source, .{}) catch |err| switch (err) {
            error.OutOfMemory,
            error.Overflow,
            => return error.OutOfMemory,
            error.InvalidCharacter,
            error.UnexpectedToken,
            error.InvalidNumber,
            error.InvalidEnumTag,
            error.DuplicateField,
            error.UnknownField,
            error.MissingField,
            error.LengthMismatch,
            error.SyntaxError,
            error.UnexpectedEndOfInput,
            error.BufferUnderrun,
            error.ValueTooLong,
            => return error.InvalidConfig,
        };
        defer parsed.deinit();

        inline for (std.meta.fields(OptionalDisplayOptions)) |field| {
            if (@field(parsed.value, field.name)) |value| {
                @field(options, field.name) = value;
            }
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
