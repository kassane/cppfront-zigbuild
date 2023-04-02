const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});

    const cpp2file = b.option([]const u8, "cpp2", "Input - Cpp2 Source file") orelse "examples/pure2-hello.cpp2";
    const cpp2pure = b.option(bool, "pure", "Allow Cpp2 syntax only [default: false]") orelse false;

    const cppfront = cpp2cpp1(b, optimize, target, .{
        .file = cpp2file,
        .pure = cpp2pure,
    });
    const cpp2_step = b.step("cppfront", "Run cppfront build (cpp2 -> cpp1)");
    cpp2_step.dependOn(&cppfront.step);

    example_build(b, optimize, target, .{
        .name = filename(cpp2file),
        .file = b.fmt("examples/{s}.cpp", .{filename(cpp2file)}),
    });
}

// convert cpp2 to cpp
fn cpp2cpp1(b: *std.Build, optimize: std.builtin.Mode, target: std.zig.CrossTarget, config: cpp2Config) *std.build.RunStep {
    const exe = b.addExecutable(.{
        .name = "cppfront",
        .target = target,
        .optimize = optimize,
    });
    exe.disable_sanitize_c = true;
    exe.addCSourceFile("vendor/cppfront/source/cppfront.cpp", cflags);
    exe.linkLibCpp();
    b.installArtifact(exe);

    const cppfrontPath = root_path ++ "zig-out/bin/cppfront";
    const cmds: []const []const u8 = if (config.pure) &.{
        cppfrontPath,
        "-p",
        config.file,
    } else &.{
        cppfrontPath,
        config.file,
    };
    const cmd = b.addSystemCommand(cmds);
    cmd.step.dependOn(b.getInstallStep());
    return cmd;
}
const cpp2Config = struct {
    file: []const u8,
    pure: bool,
};
fn example_build(b: *std.Build, mode: std.builtin.Mode, target: std.zig.CrossTarget, info: BuildInfo) void {
    const example = b.addExecutable(.{
        .name = info.name,
        .target = target,
        .optimize = mode,
    });
    example.disable_sanitize_c = true;
    if (target.isWindows())
        example.want_lto = false;
    example.addCSourceFile(info.file, cflags);
    example.addIncludePath("vendor/cppfront/include");
    example.linkLibCpp();
    // b.installArtifact(example);

    const run_cmd = b.addRunArtifact(example); //run on zig-cache (latest build)
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run C++ example code");
    run_step.dependOn(&run_cmd.step);
    // return run_cmd;
}

const BuildInfo = struct {
    name: []const u8,
    file: []const u8,
};

fn root() []const u8 {
    return std.fs.path.dirname(@src().file) orelse unreachable;
}
const root_path = root() ++ "/";

const cflags = &.{
    "-Wall",
    "-Wextra",
    "-std=c++20",
    "-fexperimental-library",
};

pub fn filename(path: []const u8) []const u8 {
    var split = std.mem.split(u8, std.fs.path.basename(path), ".");
    return split.first();
}
