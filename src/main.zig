const std = @import("std");
const clap = @import("clap");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const NormalizedSizeUnit = struct {
    order: usize,

    fn getName(self: NormalizedSizeUnit) []const u8 {
        return switch (self.order) {
            0 => "B",
            1 => "KiB",
            2 => "MiB",
            3 => "GiB",
            4 => "TiB",
            5 => "PiB",
            6 => "EiB",
            7 => "ZiB",
            8 => "YiB",
            else => ">>B",
        };
    }
};

const NormalizedSize = struct {
    magnitude: f64,
    unit: NormalizedSizeUnit,
};

fn normalizeSize(bytes: u64) NormalizedSize {
    var size = NormalizedSize{ .magnitude = @floatFromInt(bytes), .unit = .{ .order = 0 } };

    while (size.magnitude >= 1024) {
        size.magnitude /= 1024;
        size.unit.order += 1;
    }

    return size;
}

fn normalizeSizeFmt(bytes: u64) struct { f64, []const u8 } {
    const res = normalizeSize(bytes);
    return .{ res.magnitude, res.unit.getName() };
}

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
        } else try writer.print("File size: {} bytes ({d:.2} {s})\n", .{count} ++ normalizeSizeFmt(count));
    }
}

pub fn main() !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help            Display this help and exit.
        \\--color               Enable output coloring
        \\--no-color            Disable output coloring
        \\--uppercase           Print uppercase hexadecimal
        \\--no-size             Do not show the file size at the end
        \\<file>                The file to open
    );

    const clap_parsers = comptime .{
        .file = clap.parsers.string,
    };
    var clap_diag = clap.Diagnostic{};
    var clap_res = clap.parse(clap.Help, &params, clap_parsers, .{ .diagnostic = &clap_diag }) catch |e| {
        clap_diag.report(std.io.getStdErr().writer(), e) catch {};
        std.process.exit(1);
    };
    defer clap_res.deinit();

    if (clap_res.args.help != 0) return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});

    if (clap_res.positionals.len != 1) {
        try std.io.getStdErr().writer().print("Expected one positional, found {}\n", .{clap_res.positionals.len});
        std.process.exit(1);
    }

    const filename = clap_res.positionals[0];

    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const stdout = std.io.getStdOut();

    const color_mode_default = stdout.supportsAnsiEscapeCodes();

    const color_mode = if (clap_res.args.color != 0 and clap_res.args.@"no-color" == 0) true else if (clap_res.args.@"no-color" != 0 and clap_res.args.color == 0) false else if (clap_res.args.color == 0 and clap_res.args.@"no-color" == 0) color_mode_default else {
        try std.io.getStdErr().writer().print("--color and --no-color cannot be specified at the same time\n", .{});
        std.process.exit(1);
    };

    try display(file.reader(), stdout.writer(), .{
        .color = color_mode,
        .uppercase = clap_res.args.uppercase != 0,
        .show_size = clap_res.args.@"no-size" == 0,
    });
}
