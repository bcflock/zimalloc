
const std = @import("std");

pub fn build (b: *std.Build) void{

    const target = b.standardTargetOptions(.{});
    const opti = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name="zimalloc",
        .root_source_file = b.path("src/hello.zig"),
        .optimize = opti,
        .target = target,
    });

    exe.addIncludePath(b.path("bin"));
    exe.addIncludePath(b.path("include"));

    exe.addObjectFile(b.path("out/release/libmimalloc.a"));

    exe.linkLibC();
    
    b.installArtifact(exe);
}
