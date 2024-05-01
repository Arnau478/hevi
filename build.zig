const std = @import("std");
const Ast = std.zig.Ast;

const SemanticVersion = std.SemanticVersion;

fn getVersion(b: *std.Build) SemanticVersion {
    var ast = Ast.parse(b.allocator, @embedFile("build.zig.zon"), .zon) catch @panic("OOM");
    defer ast.deinit(b.allocator);

    var buf: [2]Ast.Node.Index = undefined;
    const build_zon = ast.fullStructInit(&buf, ast.nodes.items(.data)[0].lhs) orelse @panic("Cannot parse build.zig.zon");

    var version: SemanticVersion = r: {
        for (build_zon.ast.fields) |field| {
            const field_name = ast.tokenSlice(ast.firstToken(field) - 2);

            if (std.mem.eql(u8, field_name, "version")) {
                const version_string = std.mem.trim(u8, ast.tokenSlice(ast.firstToken(field)), "\"");
                break :r SemanticVersion.parse(version_string) catch @panic("Version parsing failed");
            }
        }
        @panic("Unable to find 'version' in build.zig.zon");
    };

    var code: u8 = undefined;
    const git_version_cmd = std.mem.trim(u8, b.runAllowFail(&[_][]const u8{
        "git",
        "describe",
        "--tags",
        "--abbrev=10",
    }, &code, .Ignore) catch {
        version.pre = "dev";
        return version;
    }, "\n\r");

    switch (std.mem.count(u8, git_version_cmd, "-")) {
        0 => return version, // Here version == git_version_cmd
        2 => {
            var splitted = std.mem.splitScalar(u8, git_version_cmd, '-');
            _ = splitted.first(); // Git tag
            const commit_num = splitted.next() orelse @panic("Wrong `git describe` output!");
            const commit_id = splitted.next() orelse @panic("Wrong `git describe` output!");

            // The commit_id always starts with 'g' (for indicate that git was used), so we can skip it
            return SemanticVersion{
                .major = version.major,
                .minor = version.minor,
                .patch = version.patch,
                .pre = b.fmt("dev.{s}", .{commit_num}),
                .build = commit_id[1..],
            };
        },
        else => {
            version.pre = "dev";
            return version;
        },
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
    build_options.addOption(SemanticVersion, "version", getVersion(b));
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
