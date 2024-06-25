const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cppfront_dep = b.dependency("cppfront", .{});

    const cpp2file = b.option([]const u8, "cpp2", "Input - Cpp2 Source file") orelse "examples/pure2-hello.cpp2";
    const cpp2pure = b.option(bool, "pure", "Allow Cpp2 syntax only [default: false]") orelse false;

    const cppfront = cpp2cpp1(b, .{
        .file = cpp2file,
        .pure = cpp2pure,
        .dependency = cppfront_dep,
        .target = target,
        .optimize = optimize,
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
fn cpp2cpp1(b: *std.Build, config: cpp2Config) *std.Build.Step.Run {
    const exe = b.addExecutable(.{
        .name = "cppfront",
        .target = config.target,
        .optimize = config.optimize,
    });

    exe.addCSourceFiles(.{
        .root = config.dependency.path(""),
        .files = &.{"source/cppfront.cpp"},
        .flags = cflags,
    });
    if (exe.rootModuleTarget().abi != .msvc)
        exe.linkLibCpp()
    else
        exe.linkLibC();
    b.installArtifact(exe);

    const cppfront = b.pathJoin(&.{ b.install_prefix, "bin", "cppfront" });
    var cppfront_exec = b.addSystemCommand(&.{cppfront});
    if (config.pure)
        cppfront_exec.addArg("-p");
    if (b.verbose)
        cppfront_exec.addArg("-verb");

    cppfront_exec.addArgs(&.{
        config.file,
        "-o",
        config.file[0 .. config.file.len - 1], // rename cpp2 to cpp
    });

    cppfront_exec.step.dependOn(b.getInstallStep());
    return cppfront_exec;
}
const cpp2Config = struct {
    file: []const u8,
    pure: bool,
    dependency: *std.Build.Dependency,
    optimize: std.builtin.OptimizeMode,
    target: std.Build.ResolvedTarget,
};
fn example_build(b: *std.Build, info: BuildInfo) void {
    const example = b.addExecutable(.{
        .name = info.filename(),
        .target = info.target,
        .optimize = info.optimize,
    });
    example.root_module.sanitize_c = false;
    if (example.rootModuleTarget().os.tag == .windows)
        example.want_lto = false;
    example.addCSourceFile(.{
        .file = b.path(b.fmt("examples/{s}.cpp", .{info.filename()})),
        .flags = cflags,
    });
    example.addIncludePath(info.dependency.path("include"));
    if (example.rootModuleTarget().abi != .msvc)
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
    target: std.Build.ResolvedTarget,
    dependency: *std.Build.Dependency,
    pub fn filename(self: BuildInfo) []const u8 {
        var split = std.mem.splitAny(u8, std.fs.path.basename(self.file), ".");
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
