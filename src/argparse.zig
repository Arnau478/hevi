const build_options = @import("build_options");
const std = @import("std");

const parsers = @import("parser.zig").parsers;

pub const ParseResult = struct {
    filename: []const u8,
    color: ?bool,
    uppercase: ?bool,
    show_size: ?bool,
    show_offset: ?bool,
    show_ascii: ?bool,
    skip_lines: ?bool,
    parser: ?[]const u8,
};

const Flag = union(enum) {
    action: struct {
        flag: []const u8,
        action: enum {
            help,
            version,
        },
    },
    toggle: struct {
        boolean: *?bool,
        enable: []const u8,
        disable: []const u8,
    },
    string: struct {
        flag: []const u8,
        val: *?[]const u8,
    },
};

fn printError(comptime fmt: []const u8, args: anytype) noreturn {
    std.debug.print("Error: " ++ fmt ++ "\nTip: use `--help` for help\n", args);
    std.process.exit(1);
}

fn printHelp() noreturn {
    const parser_list: [parsers.len][]const u8 = comptime v: {
        var list: [parsers.len][]const u8 = undefined;
        var pos: usize = 0;
        for (parsers) |parser| {
            var split = std.mem.splitAny(u8, @typeName(parser), ".");
            _ = split.first();

            list[pos] = split.next().?;
            pos += 1;
        }
        break :v list;
    };

    std.debug.print(
        \\hevi - hex viewer
        \\
        \\Usage:
        \\  hevi <file> [flags]
        \\
        \\Flags:
        \\  -h, --help                      Print this help message
        \\  -v, --version                   Print version information
        \\  --color, --no-color             Enable or disable output coloring
        \\  --lowercase, --uppercase        Switch between lowercase and uppercase hex
        \\  --size, --no-size               Enable or disable showing the size at the end
        \\  --offset, --no-offset           Enable or disable the offset at the left
        \\  --ascii, --no-ascii             Enable or disable the ASCII output
        \\  --skip-lines, --no-skip-lines   Enable or disable skipping of identical lines
        \\  --parser                        Specify the parser to use. Available parsers:
        \\
    , .{});

    for (parser_list) |parser| {
        // How many tabs (4 spaces) we want to print
        for (0..9) |_| {
            std.debug.print("    ", .{});
        }
        std.debug.print("- {s}\n", .{parser});
    }

    std.debug.print(
        \\
        \\Made by Arnau478
        \\
    , .{});
    std.process.exit(0);
}

fn printVersion() noreturn {
    const version = build_options.version;

    if (version.build != null) {
        // Development version
        std.debug.print(
            \\hevi {d}.{d}.{d}-{s}+{s}
            \\
        , .{
            version.major,
            version.minor,
            version.patch,
            version.pre.?,
            version.build.?,
        });
    } else if (version.pre != null) {
        // Development version because git information is not available
        std.debug.print(
            \\hevi {d}.{d}.{d}-{s}
            \\
        , .{
            version.major,
            version.minor,
            version.patch,
            version.pre.?,
        });
    } else {
        // Tagged version
        std.debug.print(
            \\hevi {d}.{d}.{d}
            \\
        , .{ version.major, version.minor, version.patch });
    }

    std.process.exit(0);
}

pub fn parse(args: [][]const u8) ParseResult {
    var filename: ?[]const u8 = null;
    var color: ?bool = null;
    var uppercase: ?bool = null;
    var show_size: ?bool = null;
    var show_offset: ?bool = null;
    var show_ascii: ?bool = null;
    var skip_lines: ?bool = null;
    var parser: ?[]const u8 = null;

    var take_string: bool = false;
    var string_ptr: *?[]const u8 = undefined;
    for (args) |arg| {
        if (take_string) {
            if (arg[0] == '-') printError("expected arg string!", .{});
            string_ptr.* = arg;

            take_string = false;
            continue;
        }

        if (arg[0] == '-') {
            if (arg.len <= 1) {
                printError("expected flag", .{});
            }
            switch (arg[1]) {
                'h' => {
                    printHelp();
                },
                'v' => {
                    printVersion();
                },
                '-' => {
                    const name = arg[2..];
                    if (name.len == 0) printError("expected flag", .{});

                    const flags: []const Flag = &.{
                        .{ .action = .{ .flag = "help", .action = .help } },
                        .{ .action = .{ .flag = "version", .action = .version } },
                        .{ .toggle = .{ .boolean = &color, .enable = "color", .disable = "no-color" } },
                        .{ .toggle = .{ .boolean = &uppercase, .enable = "uppercase", .disable = "lowercase" } },
                        .{ .toggle = .{ .boolean = &show_size, .enable = "size", .disable = "no-size" } },
                        .{ .toggle = .{ .boolean = &show_offset, .enable = "offset", .disable = "no-offset" } },
                        .{ .toggle = .{ .boolean = &show_ascii, .enable = "ascii", .disable = "no-ascii" } },
                        .{ .toggle = .{ .boolean = &skip_lines, .enable = "skip-lines", .disable = "no-skip-lines" } },
                        .{ .string = .{ .flag = "parser", .val = &parser } },
                    };

                    const found = blk: {
                        for (flags) |flag| {
                            switch (flag) {
                                .action => |action| {
                                    if (std.mem.eql(u8, name, action.flag)) {
                                        switch (action.action) {
                                            .help => printHelp(),
                                            .version => printVersion(),
                                        }
                                        break :blk true;
                                    }
                                },
                                .toggle => |toggle| {
                                    var set: ?bool = null;
                                    if (std.mem.eql(u8, name, toggle.enable)) {
                                        set = true;
                                    } else if (std.mem.eql(u8, name, toggle.disable)) {
                                        set = false;
                                    }

                                    if (set) |s| {
                                        if (toggle.boolean.* != null) {
                                            if (toggle.boolean.*.? != s) {
                                                printError("`--{s}` and `--{s}` are mutually exclusive", .{ toggle.enable, toggle.disable });
                                            } else printError("`--{s}` specified multiple times", .{if (s) toggle.enable else toggle.disable});
                                        } else toggle.boolean.* = s;

                                        break :blk true;
                                    }
                                },
                                .string => |string| {
                                    take_string = true;
                                    string_ptr = string.val;

                                    break :blk true;
                                },
                            }
                        }
                        break :blk false;
                    };

                    if (!found) printError("invalid flag `{s}`", .{arg});
                },
                else => printError("invalid flag `{s}`", .{arg}),
            }
        } else {
            if (filename) |_| {
                printError("multiple files specified", .{});
            } else filename = arg;
        }
    }

    return .{
        .filename = filename orelse printError("no file specified", .{}),
        .color = color,
        .uppercase = uppercase,
        .show_size = show_size,
        .show_offset = show_offset,
        .show_ascii = show_ascii,
        .skip_lines = skip_lines,
        .parser = parser,
    };
}
