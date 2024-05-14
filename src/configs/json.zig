const std = @import("std");

const hevi = @import("hevi");

pub fn getConfigPath() []const u8 {
    return "config.json";
}

pub fn parse(options: *hevi.DisplayOptions, allocator: std.mem.Allocator, file: std.fs.File) !void {
    const source = try file.readToEndAllocOptions(allocator, std.math.maxInt(usize), null, 1, 0);
    defer allocator.free(source);

    const OptionalDisplayOptions = struct {
        color: ?bool = null,
        uppercase: ?bool = null,
        show_size: ?bool = null,
        show_offset: ?bool = null,
        show_ascii: ?bool = null,
        skip_lines: ?bool = null,
        parser: ?hevi.Parser = null,

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
