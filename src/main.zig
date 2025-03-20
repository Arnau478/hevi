const std = @import("std");
const hevi = @import("hevi");
const build_options = @import("build_options");
const pennant = @import("pennant");
const options = @import("options.zig");

pub const std_options = std.Options{
    .logFn = logFn,
};

fn logFn(comptime message_level: std.log.Level, comptime scope: @Type(.enum_literal), comptime format: []const u8, args: anytype) void {
    const level_txt = comptime message_level.asText();
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    const stderr = std.io.getStdErr();
    var bw = std.io.bufferedWriter(stderr.writer());
    const writer = bw.writer();

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();

    const log_color = stderr.supportsAnsiEscapeCodes();

    const col = switch (message_level) {
        .err => "31",
        .warn => "33",
        .info => "34",
        .debug => "37",
    };

    nosuspend {
        writer.print(
            "{s}{s}{s}" ++ level_txt ++ "{s}",
            if (log_color) .{ "\x1b[", col, "m\x1b[1m", "\x1b[0m" } else .{ "", "", "", "" },
        ) catch return;
        writer.print(prefix2 ++ format ++ "\n", args) catch return;
        bw.flush() catch return;
    }
}

pub fn fail(comptime fmt: []const u8, args: anytype) noreturn {
    std.log.err(fmt, args);
    std.process.exit(1);
}

fn printPalette(opts: hevi.DisplayOptions, writer: anytype) !void {
    try writer.print("                  (alt)    (accent)\n", .{});
    try writer.print("(main)   ", .{});
    try opts.palette.normal.ansiCode(writer);
    try writer.print("0x112233\x1b[0m ", .{});
    try opts.palette.normal_alt.ansiCode(writer);
    try writer.print("0x112233\x1b[0m ", .{});
    try opts.palette.normal_accent.ansiCode(writer);
    try writer.print("0x112233\x1b[0m\n", .{});

    inline for (0..5) |i| {
        const name = std.fmt.comptimePrint("c{d}", .{i + 1});
        try writer.print("         ", .{});
        try @field(opts.palette, name).ansiCode(writer);
        try writer.print("0x112233\x1b[0m ", .{});
        try @field(opts.palette, name ++ "_alt").ansiCode(writer);
        try writer.print("0x112233\x1b[0m ", .{});
        try @field(opts.palette, name ++ "_accent").ansiCode(writer);
        try writer.print("0x112233\x1b[0m\n", .{});
    }
}

fn printVersion() void {
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
}

pub const CliOptions = struct {
    help: bool = false,
    version: bool = false,
    @"show-palette": bool = false,
    color: ?bool = null,
    uppercase: ?bool = null,
    size: ?bool = null,
    offset: ?bool = null,
    ascii: ?bool = null,
    @"skip-lines": ?bool = null,
    raw: ?bool = null,
    parser: ?hevi.Parser = null,

    pub const shorthands = .{
        .h = "help",
        .v = "version",
    };

    pub const opposites = .{
        .color = "no-color",
        .uppercase = "lowercase",
        .size = "no-size",
        .offset = "no-offset",
        .ascii = "no-ascii",
        .@"skip-lines" = "no-skip-lines",
    };

    pub const descriptions = .{
        .help = "Print this help message",
        .version = "Print version information",
        .@"show-palette" = "Print the color palette being used",
        .color = "Colored output",
        .uppercase = "Lowercase or uppercase hexadecimal",
        .size = "Show the file size at the end",
        .offset = "Show the offset into the file at each line",
        .ascii = "Show the ASCII interpretation",
        .@"skip-lines" = "Skip identical lines",
        .raw = "Raw format (disables most features)",
        .parser = "The parser to use",
    };
};

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) fail("Memory leak detected", .{});

    const allocator = gpa.allocator();

    const args_res = pennant.parseForProcess(CliOptions, allocator) catch |err| switch (err) {
        error.OutOfMemory => fail("Out of memory", .{}),
    };
    defer args_res.deinit(allocator);

    switch (args_res) {
        .valid => |args| {
            const stdout = std.io.getStdOut();

            const opts = options.getOptions(allocator, args.options, stdout) catch |err| switch (err) {
                error.InvalidConfig => fail("Invalid config found", .{}),
                else => fail("Error getting options and config file", .{}),
            };

            if (args.options.help) {
                pennant.printHelp(CliOptions, .{ .text = 
                    \\hevi - hex viewer
                    \\
                    \\Usage:
                    \\  hevi <file>
                });
            } else if (args.options.version) {
                printVersion();
            } else if (args.options.@"show-palette") {
                printPalette(opts, stdout.writer()) catch |err| switch (err) {
                    else => fail("{s}", .{@errorName(err)}),
                };
            } else {
                if (args.positionals.len == 1) {
                    const true_filename = args.positionals[0];
                    const is_stdin = std.mem.eql(u8, true_filename, "-");
                    const filename = if (is_stdin) "<stdin>" else true_filename;

                    const file = if (is_stdin)
                        std.io.getStdIn()
                    else
                        std.fs.cwd().openFile(filename, .{}) catch |err| switch (err) {
                            error.FileNotFound => fail("{s} not found", .{filename}),
                            error.IsDir => fail("{s} is a directory", .{filename}),
                            else => fail("{s} could not be opened", .{filename}),
                        };
                    defer if (!is_stdin) file.close();

                    const data = file.readToEndAlloc(allocator, std.math.maxInt(usize)) catch |err| switch (err) {
                        error.OutOfMemory => fail("Out of memory", .{}),
                        error.IsDir => fail("{s} is a directory", .{filename}),
                        else => fail("Cannot read {s}", .{filename}),
                    };

                    defer allocator.free(data);

                    hevi.dump(allocator, data, stdout.writer(), opts) catch |err| switch (err) {
                        error.NonMatchingParser => fail("{s} does not match parser {s}", .{ filename, @tagName(opts.parser.?) }),
                        error.OutOfMemory => fail("Out of memory", .{}),
                        error.BrokenPipe => fail("Broken pipe", .{}),
                        else => fail("Error writing to stdout: {s}", .{@errorName(err)}),
                    };
                } else {
                    if (args.positionals.len == 0) {
                        std.log.err("No file specified", .{});
                    } else {
                        std.log.err("Invalid command usage", .{});
                    }
                    std.log.info("Use `--help` for help", .{});
                    std.process.exit(1);
                }
            }
        },
        .err => |err| {
            fail("{}", .{err});
        },
    }
}

test {
    _ = options;
}
