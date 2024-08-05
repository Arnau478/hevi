const builtin = @import("builtin");
const std = @import("std");
const hevi = @import("hevi");
const ziggy = @import("ziggy");
const argparse = @import("argparse.zig");

fn openConfigFile(allocator: std.mem.Allocator, env_map: std.process.EnvMap) ?std.meta.Tuple(&.{ std.fs.File, []const u8 }) {
    const path: ?[]const u8 = switch (builtin.os.tag) {
        .linux, .macos, .freebsd, .openbsd, .netbsd => if (env_map.get("XDG_CONFIG_HOME")) |xdg_config_home|
            std.fs.path.join(allocator, &.{ xdg_config_home, "hevi/config.ziggy" }) catch null
        else if (env_map.get("HOME")) |home|
            std.fs.path.join(allocator, &.{ home, ".config/hevi/config.ziggy" }) catch null
        else
            null,
        .windows => if (env_map.get("APPDATA")) |appdata|
            std.fs.path.join(allocator, &.{ appdata, "hevi/config.ziggy" }) catch null
        else
            null,
        else => null,
    };

    return .{ std.fs.openFileAbsolute(path orelse return null, .{}) catch {
        allocator.free(path.?);
        return null;
    }, path orelse return null };
}

const Config = struct {
    color: ?bool = null,
    uppercase: ?bool = null,
    show_size: ?bool = null,
    show_offset: ?bool = null,
    show_ascii: ?bool = null,
    skip_lines: ?bool = null,
    raw: ?bool = null,
    palette: ?Palette = null,

    const Palette = struct {
        normal: Color,
        normal_alt: Color,
        normal_accent: Color,
        c1: Color,
        c1_alt: Color,
        c1_accent: Color,
        c2: Color,
        c2_alt: Color,
        c2_accent: Color,
        c3: Color,
        c3_alt: Color,
        c3_accent: Color,
        c4: Color,
        c4_alt: Color,
        c4_accent: Color,
        c5: Color,
        c5_alt: Color,
        c5_accent: Color,

        const Color = struct {
            col: hevi.TextColor,

            fn parseBase(str: []const u8) ?hevi.TextColor.BaseColor {
                inline for (std.meta.fields(hevi.TextColor.BaseColor.Standard)) |field| {
                    if (std.mem.eql(u8, field.name, str)) {
                        return .{
                            .standard = @field(hevi.TextColor.BaseColor.Standard, field.name),
                        };
                    }
                }

                if (str.len == 7 and str[0] == '#') {
                    return .{
                        .true_color = .{
                            .r = std.fmt.parseUnsigned(u8, str[1..3], 16) catch return null,
                            .g = std.fmt.parseUnsigned(u8, str[3..5], 16) catch return null,
                            .b = std.fmt.parseUnsigned(u8, str[5..7], 16) catch return null,
                        },
                    };
                }

                return null;
            }

            pub fn fromString(str: []const u8) ?Color {
                var iter = std.mem.splitScalar(u8, str, ':');

                const fg = iter.next() orelse return null;

                var maybe_bg = iter.next();
                if (maybe_bg) |bg| {
                    if (bg.len == 0) maybe_bg = null;
                }

                const maybe_mod = iter.next();

                if (iter.next() != null) return null;

                var dim = false;
                var bold = false;

                if (maybe_mod) |mod| {
                    if (std.mem.eql(u8, mod, "dim")) {
                        dim = true;
                    } else if (std.mem.eql(u8, mod, "bold")) {
                        bold = true;
                    } else {
                        return null;
                    }
                }

                return .{
                    .col = .{
                        .foreground = parseBase(fg) orelse return null,
                        .background = if (maybe_bg) |bg| parseBase(bg) orelse return null else null,
                        .dim = dim,
                        .bold = bold,
                    },
                };
            }

            pub const ziggy_options = struct {
                pub fn parse(parser: *ziggy.Parser, first_tok: ziggy.Tokenizer.Token) !Color {
                    try parser.must(first_tok, .at);
                    const ident = try parser.nextMust(.identifier);
                    if (!std.mem.eql(u8, ident.loc.src(parser.code), "color")) {
                        return parser.addError(.{
                            .syntax = .{
                                .name = "@color",
                                .sel = ident.loc.getSelection(parser.code),
                            },
                        });
                    }
                    _ = try parser.nextMust(.lp);
                    const str = try parser.nextMust(.string);
                    _ = try parser.nextMust(.rp);

                    return Color.fromString(str.loc.unquote(parser.code) orelse {
                        return parser.addError(.{
                            .syntax = .{
                                .name = first_tok.tag.lexeme(),
                                .sel = first_tok.loc.getSelection(parser.code),
                            },
                        });
                    }) orelse {
                        return parser.addError(.{
                            .syntax = .{
                                .name = first_tok.tag.lexeme(),
                                .sel = first_tok.loc.getSelection(parser.code),
                            },
                        });
                    };
                }
            };

            pub fn toHevi(self: Color) hevi.TextColor {
                return self.col;
            }
        };

        pub fn toHevi(self: Palette) hevi.ColorPalette {
            return .{
                .normal = self.normal.toHevi(),
                .normal_alt = self.normal_alt.toHevi(),
                .normal_accent = self.normal_accent.toHevi(),
                .c1 = self.c1.toHevi(),
                .c1_alt = self.c1_alt.toHevi(),
                .c1_accent = self.c1_accent.toHevi(),
                .c2 = self.c2.toHevi(),
                .c2_alt = self.c2_alt.toHevi(),
                .c2_accent = self.c2_accent.toHevi(),
                .c3 = self.c3.toHevi(),
                .c3_alt = self.c3_alt.toHevi(),
                .c3_accent = self.c3_accent.toHevi(),
                .c4 = self.c4.toHevi(),
                .c4_alt = self.c4_alt.toHevi(),
                .c4_accent = self.c4_accent.toHevi(),
                .c5 = self.c5.toHevi(),
                .c5_alt = self.c5_alt.toHevi(),
                .c5_accent = self.c5_accent.toHevi(),
            };
        }
    };
};

pub fn getOptions(allocator: std.mem.Allocator, args: argparse.ParseResult, stdout: std.fs.File) !hevi.DisplayOptions {
    var envs = try std.process.getEnvMap(allocator);
    defer envs.deinit();

    // Default values
    var options = hevi.DisplayOptions{
        .color = stdout.getOrEnableAnsiEscapeSupport(),
        .uppercase = false,
        .show_size = true,
        .show_offset = true,
        .show_ascii = true,
        .skip_lines = true,
        .raw = false,
    };

    // Config file
    if (openConfigFile(allocator, envs)) |tuple| {
        defer {
            tuple[0].close();
            allocator.free(tuple[1]);
        }

        const source = try tuple[0].readToEndAllocOptions(allocator, std.math.maxInt(usize), null, 1, 0);
        defer allocator.free(source);

        if (source.len != 0) {
            var arena = std.heap.ArenaAllocator.init(allocator);
            defer arena.deinit();

            var diag = ziggy.Diagnostic{ .path = tuple[1] };
            defer diag.deinit(arena.allocator());

            const config = ziggy.parseLeaky(Config, arena.allocator(), source, .{
                .diagnostic = &diag,
            }) catch |err| switch (err) {
                error.OutOfMemory, error.Overflow => return error.OutOfMemory,
                error.Syntax => {
                    std.log.err("{}", .{diag});
                    return error.InvalidConfig;
                },
            };

            if (config.color) |color| options.color = color;
            if (config.uppercase) |uppercase| options.uppercase = uppercase;
            if (config.show_size) |show_size| options.show_size = show_size;
            if (config.show_offset) |show_offset| options.show_offset = show_offset;
            if (config.show_ascii) |show_ascii| options.show_ascii = show_ascii;
            if (config.skip_lines) |skip_lines| options.skip_lines = skip_lines;
            if (config.raw) |raw| options.raw = raw;
            if (config.palette) |palette| options.palette = palette.toHevi();
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
    if (args.raw) |raw| options.raw = raw;
    if (args.parser) |parser| options.parser = parser;

    return options;
}
