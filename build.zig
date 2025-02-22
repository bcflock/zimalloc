
const std = @import("std");
const builtin = @import("builtin");

const c_source_files = [_][]const u8 {
    "src/alloc.c",
    "src/alloc.c",
    "src/alloc-override.c",
    "src/alloc-posix.c",
    "src/arena-abandon.c",
    "src/arena.c",
    "src/bitmap.c",
    "src/bitmap.h",
    "src/free.c",
    "src/heap.c",
    "src/init.c",
    "src/libc.c",
    "src/options.c",
    "src/os.c",
    "src/page.c",
    "src/page-queue.c",
    "src/random.c",
    "src/segment.c",
    "src/segment-map.c",
    "src/static.c",
    "src/stats.c",
};

const windows_c_source_files = [_][]const u8 {
    "src/prim/windows/prim.c"
};

const unix_c_source_files = [_][]const u8 {
    "src/prim/unix/prim.c"
};

const c_flags = [_][]const u8{
    "-Wall",
    "-Wextra",
    "-Werror"
};

const inc_path: std.Build.path = "./include";

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
