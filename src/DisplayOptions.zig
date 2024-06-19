const std = @import("std");
const hevi = @import("hevi.zig");

const DisplayOptions = @This();

/// Whether to use color or not
color: bool,
/// If true, uses uppercase; otherwise lowercase
uppercase: bool,
/// Print the size of the file at the end
show_size: bool,
/// Show a column with the offset into the file
show_offset: bool,
/// Show a column with the ASCII interpretation
show_ascii: bool,
/// Skip lines if they're the same as the one before and after it
skip_lines: bool,
/// Raw dump (no offset, no lines skipped, no decorations, etc.)
raw: bool = false,
/// Override the binary parser that is used
parser: ?hevi.Parser = null,
/// The color palette to use (ignored if `color` is `false`)
palette: hevi.ColorPalette = hevi.default_palette,
