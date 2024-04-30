const std = @import("std");

const VERSION = "1.0.0";

fn getVersion(b: *std.Build) []const u8 {
    var code: u8 = undefined;
    const git_version_cmd = std.mem.trim(u8, b.runAllowFail(&[_][]const u8{
        "git",
        "describe",
        "--tags",
        "--abbrev=10",
    }, &code, .Ignore) catch {
        return VERSION;
    }, "\n\r");

    switch (std.mem.count(u8, git_version_cmd, "-")) {
        0 => return git_version_cmd, // Here VERSION == git_version_cmd
        2 => {
            var splitted = std.mem.splitScalar(u8, git_version_cmd, '-');
            _ = splitted.first(); // Git tag
            const commit_num = splitted.next() orelse @panic("Wrong `git describe` output!");
            const commit_id = splitted.next() orelse @panic("Wrong `git describe` output!");

            // The commit_id always starts with 'g' (for indicate that git was used), so we can skip it
            return b.fmt("{s}-dev.{s}+{s}", .{ VERSION, commit_num, commit_id[1..] });
        },
        else => return VERSION,
    }
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "hevi",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    var build_options = b.addOptions();
    build_options.addOption([]const u8, "version", getVersion(b));
    exe.root_module.addOptions("build_options", build_options);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
