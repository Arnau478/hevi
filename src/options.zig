const builtin = @import("builtin");
const std = @import("std");
const hevi = @import("hevi");
const argparse = @import("argparse.zig");

fn openConfigFile(allocator: std.mem.Allocator, env_map: std.process.EnvMap) ?std.meta.Tuple(&.{ std.fs.File, []const u8 }) {
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

        const stderr = std.io.getStdErr();
        defer stderr.close();

        const source = try tuple[0].readToEndAllocOptions(allocator, std.math.maxInt(usize), null, 1, 0);
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
            const value = if (ast.tokens.get(ast.firstToken(field)).tag == .identifier or ast.tokens.get(ast.firstToken(field)).tag == .string_literal)
                slice
            else {
                try stderr.writer().print("Error: invalid config found\n", .{});
                return error.InvalidConfig;
            };

            inline for (std.meta.fields(hevi.DisplayOptions)) |opt_field| {
                if (std.mem.eql(u8, name, opt_field.name)) {
                    @field(options, opt_field.name) = switch (opt_field.type) {
                        bool => if (std.mem.eql(u8, value, "false"))
                            false
                        else if (std.mem.eql(u8, value, "true"))
                            true
                        else {
                            try stderr.writer().print("Error: expected a bool for field {s} in config file\n", .{name});
                            return error.InvalidConfig;
                        },
                        hevi.DisplayOptions.OptionString, ?hevi.DisplayOptions.OptionString => .{ .is_allocated = true, .string = std.mem.trim(u8, try allocator.dupe(u8, value), "\"") },
                        else => {
                            try stderr.writer().print("Error: expected a {s} for field {s} in config file\n", .{ @typeName(opt_field.type), name });
                            return error.InvalidConfig;
                        },
                    };
                }
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
    if (args.parser) |parser| hevi.DisplayOptions.OptionString.safeSet(allocator, &options, parser);

    return options;
}
