
const std = @import("std")
const builtin = @import("builtin")

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
    "src/prim",
    "src/random.c",
    "src/segment.c",
    "src/segment-map.c",
    "src/static.c",
    "src/stats.c",
}

const windows_c_source_files = [_][]const u8 {
    "src/prim/windows/prim.c"
}

const unix_c_source_files = [_][]const u8 {
    "src/prim/unix/prim.c"
}

const c_flags = [_][]const u8{
    "-Wall",
    "-Wextra",
    "-Werror"
}

const inc_path: std.Build.LazyPath = .{
    .path = "./include"
}

pub fn build (b: *std.Build) void{
    const build_options = b.addOptions();

    const target = b.standardTargetOptions(.{});
    const opti = b.standardOptimizeOption(.{});
    const lib = b.addStaticLibrary(.{
        .name="zimalloc",
        .optimize = opti,
        .target = target,
    })

    lib.addIncludePath(inc_path);
    lib.addCSourceFiles(
        &c_source_files, &c_flags
    );

    switch(builtin.target.os.tag) {
        .windows => {
            lib.addCSourceFiles(
                &windows_c_source_files, &c_flags
            )
        },
        .linux => {
            lib.addCSourceFiles(
                &unix_c_source_files,
                &c_flags
            );
        },
        else => {}
    }
    lib.linkLibC();
}
