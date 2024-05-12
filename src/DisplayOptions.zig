const std = @import("std");
const DisplayOptions = @This();

color: bool,
uppercase: bool,
show_size: bool,
show_offset: bool,
show_ascii: bool,
skip_lines: bool,
parser: ?OptionString,

pub const OptionString = struct {
    is_allocated: bool = false,
    string: []const u8,

    pub fn safeSet(allocator: std.mem.Allocator, options: *DisplayOptions, s: []const u8) void {
        if (options.parser) |parser| {
            if (parser.is_allocated) allocator.free(parser.string);
        }

        options.parser = .{ .string = s };
    }
};

pub fn deinit(self: DisplayOptions, allocator: std.mem.Allocator) void {
    if (self.parser) |parser| {
        if (parser.is_allocated) allocator.free(parser.string);
    }
}
