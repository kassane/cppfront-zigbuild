const std = @import("std");

fn root() []const u8 {
    return std.fs.path.dirname(@src().file) orelse unreachable;
}
const root_path = root() ++ "/";

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("cppfront", null);
    exe.addCSourceFile("vendor/cppfront/source/cppfront.cpp", &[_][]const u8{ "-std=c++20", "-Wall" });
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.linkLibCpp();
    exe.linkLibC();
    exe.install();

    const cppfront = cpp2cpp1(b);
    const cpp2_step = b.step("cppfront", "Run cppfront build (cpp2 -> cpp1)");
    cpp2_step.dependOn(&cppfront.step);

    const run_cmd = example_build(b, mode, target);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("hello_cpp", "Run hello C++ example code");
    run_step.dependOn(&run_cmd.step);
}

// convert cpp2 to cpp
fn cpp2cpp1(b: *std.build.Builder) *std.build.RunStep {
    const cppfrontPath = root_path ++ "zig-out/bin/cppfront";
    const cmd = b.addSystemCommand(&[_][]const u8{
        cppfrontPath,
        // "-p",
        "example/hello.cpp2",
    });
    return cmd;
}

fn example_build(b: *std.build.Builder, mode: std.builtin.Mode, target: std.zig.CrossTarget) *std.build.RunStep {
    const example = b.addExecutable("hello_cpp", null);
    example.addCSourceFile("example/hello.cpp", &[_][]const u8{ "-std=c++20", "-Wall" });
    example.setTarget(target);
    example.addIncludePath("vendor/cppfront/include");
    example.setBuildMode(mode);
    example.linkLibCpp();
    example.linkLibC();

    return example.run();
}
