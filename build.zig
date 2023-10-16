const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cppfront_dep = b.dependency("cppfront", .{
        .target = target,
        .optimize = optimize,
    });

    const cpp2file = b.option([]const u8, "cpp2", "Input - Cpp2 Source file") orelse "examples/pure2-hello.cpp2";
    const cpp2pure = b.option(bool, "pure", "Allow Cpp2 syntax only [default: false]") orelse false;

    const cppfront = cpp2cpp1(b, target, .{
        .file = cpp2file,
        .pure = cpp2pure,
        .dependency = cppfront_dep,
    });
    const cpp2_step = b.step("cppfront", "Run cppfront build (cpp2 -> cpp1)");
    cpp2_step.dependOn(&cppfront.step);

    example_build(b, .{
        .file = cpp2file,
        .target = target,
        .optimize = optimize,
        .dependency = cppfront_dep,
    });
}

// convert cpp2 to cpp
fn cpp2cpp1(b: *std.Build, target: std.zig.CrossTarget, config: cpp2Config) *std.build.Step.Run {
    const exe = b.addExecutable(.{
        .name = "cppfront",
        .target = target,
        .optimize = .ReleaseSafe,
    });
    exe.disable_sanitize_c = true;

    exe.addCSourceFile(.{
        .file = config.dependency.path("source/cppfront.cpp"),
        .flags = cflags,
    });
    if (target.getAbi() != .msvc)
        exe.linkLibCpp()
    else
        exe.linkLibC();
    b.installArtifact(exe);

    const cppfront = b.pathJoin(&.{ b.install_prefix, "bin/cppfront" });
    const cmds: []const []const u8 = if (config.pure) &.{
        cppfront,
        "-p",
        config.file,
    } else &.{
        cppfront,
        config.file,
    };
    const cmd = b.addSystemCommand(cmds);
    cmd.step.dependOn(b.getInstallStep());
    return cmd;
}
const cpp2Config = struct {
    file: []const u8,
    pure: bool,
    dependency: *std.Build.Dependency,
};
fn example_build(b: *std.Build, info: BuildInfo) void {
    const example = b.addExecutable(.{
        .name = info.filename(),
        .target = info.target,
        .optimize = info.optimize,
    });
    example.disable_sanitize_c = true;
    if (info.target.isWindows())
        example.want_lto = false;
    example.addCSourceFile(.{
        .file = .{ .path = b.fmt("examples/{s}.cpp", .{info.filename()}) },
        .flags = cflags,
    });
    example.addIncludePath(info.dependency.path("include"));
    if (info.target.getAbi() != .msvc)
        example.linkLibCpp()
    else
        example.linkLibC();

    const run_cmd = b.addRunArtifact(example);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run C++ example code");
    run_step.dependOn(&run_cmd.step);
}

const BuildInfo = struct {
    file: []const u8,
    optimize: std.builtin.OptimizeMode,
    target: std.zig.CrossTarget,
    dependency: *std.Build.Dependency,
    pub fn filename(self: BuildInfo) []const u8 {
        var split = std.mem.split(u8, std.fs.path.basename(self.file), ".");
        return split.first();
    }
};

const cflags = &.{
    "-Wall",
    "-Wextra",
    "-std=c++20",
    "-fexperimental-library",
    "-Werror",
};
