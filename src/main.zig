const std = @import("std");
const hevi = @import("hevi");
const argparse = @import("argparse.zig");
const options = @import("options.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) std.debug.print("Error: MEMORY LEAK!\n", .{});

    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const parsed_args = argparse.parse(args[1..]);

    const file = try std.fs.cwd().openFile(parsed_args.filename, .{});
    defer file.close();

    const data = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(data);

    const stdout = std.io.getStdOut();

    try hevi.dump(allocator, data, stdout.writer().any(), try options.getOptions(allocator, parsed_args, stdout));
}
