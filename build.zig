const std = @import("std");
const Ast = std.zig.Ast;

const SemanticVersion = std.SemanticVersion;

const release_targets: []const std.Target.Query = &.{
    .{ .os_tag = .linux, .cpu_arch = .x86 },
    .{ .os_tag = .linux, .cpu_arch = .x86_64 },
    .{ .os_tag = .linux, .cpu_arch = .aarch64 },
    .{ .os_tag = .windows, .cpu_arch = .x86 },
    .{ .os_tag = .windows, .cpu_arch = .x86_64 },
    .{ .os_tag = .windows, .cpu_arch = .aarch64 },
    .{ .os_tag = .macos, .cpu_arch = .x86_64 },
    .{ .os_tag = .macos, .cpu_arch = .aarch64 },
};

fn getVersion(b: *std.Build) SemanticVersion {
    if (b.option([]const u8, "force-version", "Force the version to a specific semver string")) |forced_ver| {
        return SemanticVersion.parse(forced_ver) catch @panic("Unable to parse forced version string");
    }

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
        version.pre = b.fmt("dev.{d}", .{b.option(usize, "version_commit_num", "The commit index since last release") orelse 0});
        if (b.option([]const u8, "version_commit_id", "The commit ID")) |commit_id| {
            version.build = commit_id;
        }
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

fn addExe(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, pie: ?bool, release: bool, build_options: *std.Build.Step.Options, hevi_mod: *std.Build.Module) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = if (release) b.fmt("hevi-{s}-{s}", .{ @tagName(target.result.cpu.arch), @tagName(target.result.os.tag) }) else "hevi",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.pie = pie;
    exe.root_module.addImport("hevi", hevi_mod);
    exe.root_module.addOptions("build_options", build_options);
    exe.root_module.addImport("ziggy", b.dependency("ziggy", .{}).module("ziggy"));

    return exe;
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const pie = b.option(bool, "pie", "Build a Position Independent Executable");

    var build_options = b.addOptions();
    build_options.addOption(SemanticVersion, "version", getVersion(b));

    const mod = b.addModule("hevi", .{
        .root_source_file = b.path("src/hevi.zig"),
    });

    const exe = addExe(b, target, optimize, pie, false, build_options, mod);
    b.installArtifact(exe);

    const docs_step = b.step("docs", "Build the documentation");

    const docs_obj = b.addObject(.{
        .name = "hevi",
        .target = target,
        .optimize = .Debug,
        .root_source_file = b.path("src/hevi.zig"),
    });
    docs_obj.root_module.addOptions("build_options", build_options);

    const docs = docs_obj.getEmittedDocs();

    docs_step.dependOn(&b.addInstallDirectory(.{
        .source_dir = docs,
        .install_dir = .prefix,
        .install_subdir = "docs",
    }).step);

    const web_step = b.step("web", "Build the whole web page");
    const web_wf = b.addWriteFiles();
    _ = web_wf.addCopyDirectory(b.path("web"), "", .{});
    _ = web_wf.addCopyDirectory(docs, "docs", .{});
    web_step.dependOn(&b.addInstallDirectory(.{
        .source_dir = web_wf.getDirectory(),
        .install_dir = .prefix,
        .install_subdir = "web",
    }).step);

    const release_step = b.step("release", "Create release builds for all targets");
    for (release_targets) |rt| {
        const rexe = addExe(b, b.resolveTargetQuery(rt), .ReleaseSmall, null, true, build_options, mod);
        release_step.dependOn(&b.addInstallArtifact(rexe, .{ .dest_sub_path = try std.fs.path.join(b.allocator, &.{ "release", rexe.out_filename }) }).step);
    }

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_unit_tests.root_module.addImport("hevi", mod);
    exe_unit_tests.root_module.addOptions("build_options", build_options);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const mod_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/hevi.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_mod_unit_tests = b.addRunArtifact(mod_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
    test_step.dependOn(&run_mod_unit_tests.step);
}
