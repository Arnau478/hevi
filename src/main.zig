const std = @import("std");
const hevi = @import("hevi");
const argparse = @import("argparse.zig");
const options = @import("options.zig");

pub const std_options = std.Options{
    .logFn = logFn,
};

fn logFn(comptime message_level: std.log.Level, comptime scope: @Type(.EnumLiteral), comptime format: []const u8, args: anytype) void {
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

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) fail("Memory leak detected", .{});

    const allocator = gpa.allocator();

    const args = std.process.argsAlloc(allocator) catch fail("Out of memory", .{});
    defer std.process.argsFree(allocator, args);

    const parsed_args = argparse.parse(args[1..]);

    const stdout = std.io.getStdOut();

    const opts = options.getOptions(allocator, parsed_args, stdout) catch |err| switch (err) {
        error.InvalidConfig => fail("Invalid config found", .{}),
        else => fail("Error getting options and config file", .{}),
    };

    if (parsed_args.show_palette != null and parsed_args.show_palette.?) {
        printPalette(opts, stdout.writer()) catch |err| switch (err) {
            else => fail("{s}", .{@errorName(err)}),
        };
    } else {
        if (parsed_args.filename) |filename| {
            const file = std.fs.cwd().openFile(filename, .{}) catch |err| switch (err) {
                error.FileNotFound => fail("{s} not found", .{filename}),
                error.IsDir => fail("{s} is a directory", .{filename}),
                else => fail("{s} could not be opened", .{filename}),
            };
            defer file.close();

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
            var no_args = true;
            inline for (std.meta.fields(argparse.ParseResult)) |field| {
                if (@field(parsed_args, field.name) != null) {
                    no_args = false;
                    break;
                }
            }

            if (no_args) {
                std.log.err("no file specified", .{});
                std.log.info("use `--help` for help", .{});
                std.process.exit(1);
            }

            fail("no file specified", .{});
        }
    }
}

test {
    _ = argparse;
    _ = options;
}
