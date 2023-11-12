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

fn normalizeSize(bytes: usize) NormalizedSize {
    var size = NormalizedSize{ .magnitude = @floatFromInt(bytes), .unit = .{ .order = 0 } };

    while (size.magnitude >= 1024) {
        size.magnitude /= 1024;
        size.unit.order += 1;
    }

    return size;
}

fn normalizeSizeFmt(bytes: usize) struct { f64, []const u8 } {
    const res = normalizeSize(bytes);
    return .{ res.magnitude, res.unit.getName() };
}

inline fn isPrintable(c: u8) bool {
    return switch (c) {
        0x20...0x7E => true,
        else => false,
    };
}

fn display(filename: []const u8, writer: anytype, options: struct { color: bool, uppercase: bool, show_size: bool }) !void {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const filesize = (try file.stat()).size;

    const line_count = std.math.divCeil(usize, filesize, 16) catch unreachable;

    for (0..line_count) |line_idx| {
        const line_offset = line_idx * 16;
        if (options.uppercase) {
            try writer.print("{X:0>8}", .{line_offset});
        } else {
            try writer.print("{x:0>8}", .{line_offset});
        }

        if (options.color) {
            try writer.print(" \x1b[2m|\x1b[0m ", .{});
        } else {
            try writer.print(" | ", .{});
        }

        var buf: [16]u8 = undefined;
        const line_len = try file.pread(&buf, line_offset);

        for (buf, 0..) |b, i| {
            if (i < line_len) {
                if (options.color) {
                    if (isPrintable(b)) {
                        if (options.uppercase) {
                            try writer.print("\x1b[33m{X:0>2}\x1b[0m", .{b});
                        } else {
                            try writer.print("\x1b[33m{x:0>2}\x1b[0m", .{b});
                        }
                    } else {
                        if (options.uppercase) {
                            try writer.print("\x1b[33m\x1b[2m{X:0>2}\x1b[0m", .{b});
                        } else {
                            try writer.print("\x1b[33m\x1b[2m{x:0>2}\x1b[0m", .{b});
                        }
                    }
                } else {
                    if (options.uppercase) {
                        try writer.print("{X:0>2}", .{b});
                    } else {
                        try writer.print("{x:0>2}", .{b});
                    }
                }
            } else {
                try writer.print("  ", .{});
            }

            if (i % 2 == 1 and i != 15) try writer.print(" ", .{});
        }

        if (options.color) {
            try writer.print(" \x1b[2m|\x1b[0m ", .{});
        } else {
            try writer.print(" | ", .{});
        }

        for (buf, 0..) |b, i| {
            if (i < line_len) {
                const char_buf: []const u8 = if (options.color) "\x1b[33m" ++ [_]u8{b} ++ "\x1b[0m" else &[_]u8{b};
                try writer.print("{s}", .{if (isPrintable(b)) char_buf else (if (options.color) "\x1b[2m.\x1b[0m" else ".")});
            } else {
                try writer.print(" ", .{});
            }
        }

        if (options.color) {
            try writer.print(" \x1b[2m|\x1b[0m\n", .{});
        } else {
            try writer.print(" |\n", .{});
        }
    }

    if (options.show_size) {
        if (filesize < 1024) {
            try writer.print("File size: {} bytes\n", .{filesize});
        } else try writer.print("File size: {} bytes ({d:.2} {s})\n", .{filesize} ++ normalizeSizeFmt(filesize));
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

    const color_mode_default = true;

    const color_mode = if (clap_res.args.color != 0 and clap_res.args.@"no-color" == 0) true else if (clap_res.args.@"no-color" != 0 and clap_res.args.color == 0) false else if (clap_res.args.color == 0 and clap_res.args.@"no-color" == 0) color_mode_default else {
        try std.io.getStdErr().writer().print("--color and --no-color cannot be specified at the same time\n", .{});
        std.process.exit(1);
    };

    try display(filename, std.io.getStdOut().writer(), .{
        .color = color_mode,
        .uppercase = clap_res.args.uppercase != 0,
        .show_size = clap_res.args.@"no-size" == 0,
    });
}
