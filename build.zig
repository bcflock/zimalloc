const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "mimalloc",
        .target = target,
        .optimize = optimize,
    });
    lib.addIncludePath(b.path("include"));
    lib.addIncludePath(b.path("include/mimalloc"));
    lib.linkLibC();

    const mi_version = "2";
    const mi_version_patch = "1";

    var mi_defines: std.ArrayList([]const u8) = std.ArrayList([]const u8).init(b.allocator);
    defer mi_defines.deinit();

    var mi_cflags: std.ArrayList([]const u8) = std.ArrayList([]const u8).init(b.allocator);
    defer mi_cflags.deinit();

    var mi_cflags_static: std.ArrayList([]const u8) = std.ArrayList([]const u8).init(b.allocator);
    defer mi_cflags_static.deinit();

    var mi_cflags_dynamic: std.ArrayList([]const u8) = std.ArrayList([]const u8).init(b.allocator);
    defer mi_cflags_dynamic.deinit();

    var mi_libraries: std.ArrayList([]const u8) = std.ArrayList([]const u8).init(b.allocator);
    defer mi_libraries.deinit();

    const mi_sources = [_][]const u8{
        "src/alloc.c",
        "src/alloc-aligned.c",
        "src/alloc-posix.c",
        "src/arena.c",
        "src/bitmap.c",
        "src/heap.c",
        "src/init.c",
        "src/libc.c",
        "src/options.c",
        "src/os.c",
        "src/page.c",
        "src/random.c",
        "src/segment.c",
        "src/segment-map.c",
        "src/stats.c",
        "src/prim/prim.c",
    };

    // Options
    const MI_SECURE = b.option(bool, "MI_SECURE", "Use full security mitigations") orelse false;
    var MI_DEBUG_FULL = b.option(bool, "MI_DEBUG_FULL", "Use full internal heap invariant checking in DEBUG mode") orelse false;
    const MI_PADDING = b.option(bool, "MI_PADDING", "Enable padding to detect heap block overflow") orelse false;
    const MI_OVERRIDE = b.option(bool, "MI_OVERRIDE", "Override the standard malloc interface") orelse true;
    const MI_XMALLOC = b.option(bool, "MI_XMALLOC", "Enable abort() call on memory allocation failure by default") orelse false;
    const MI_SHOW_ERRORS = b.option(bool, "MI_SHOW_ERRORS", "Show error and warning messages by default") orelse false;
    const MI_TRACK_VALGRIND = b.option(bool, "MI_TRACK_VALGRIND", "Compile with Valgrind support") orelse false;
    var MI_TRACK_ASAN = b.option(bool, "MI_TRACK_ASAN", "Compile with address sanitizer support") orelse false;
    var MI_TRACK_ETW = b.option(bool, "MI_TRACK_ETW", "Compile with Windows event tracing (ETW) support") orelse false;
    var MI_USE_CXX = b.option(bool, "MI_USE_CXX", "Use the C++ compiler to compile the library") orelse false;
    var MI_OPT_ARCH = b.option(bool, "MI_OPT_ARCH", "Only for optimized builds: turn on architecture specific optimizations") orelse true;
    const MI_SEE_ASM = b.option(bool, "MI_SEE_ASM", "Generate assembly files") orelse false;
    const MI_OSX_INTERPOSE = b.option(bool, "MI_OSX_INTERPOSE", "Use interpose to override standard malloc on macOS") orelse true;
    const MI_OSX_ZONE = b.option(bool, "MI_OSX_ZONE", "Use malloc zone to override standard malloc on macOS") orelse true;
    const MI_WIN_REDIRECT = b.option(bool, "MI_WIN_REDIRECT", "Use redirection module on Windows if compiling mimalloc as a DLL") orelse true;
    const MI_WIN_USE_FIXED_TLS = b.option(bool, "MI_WIN_USE_FIXED_TLS", "Use a fixed TLS slot on Windows") orelse false;
    const MI_LOCAL_DYNAMIC_TLS = b.option(bool, "MI_LOCAL_DYNAMIC_TLS", "Use local-dynamic-tls") orelse false;
    const MI_LIBC_MUSL = b.option(bool, "MI_LIBC_MUSL", "Set this when linking with musl libc") orelse false;
    const MI_BUILD_SHARED = b.option(bool, "MI_BUILD_SHARED", "Build shared library") orelse true;
    const MI_BUILD_STATIC = b.option(bool, "MI_BUILD_STATIC", "Build static library") orelse true;
    const MI_BUILD_OBJECT = b.option(bool, "MI_BUILD_OBJECT", "Build object library") orelse true;
    const MI_BUILD_TESTS = b.option(bool, "MI_BUILD_TESTS", "Build test executables") orelse true;
    const MI_DEBUG_TSAN = b.option(bool, "MI_DEBUG_TSAN", "Build with thread sanitizer") orelse false;
    const MI_DEBUG_UBSAN = b.option(bool, "MI_DEBUG_UBSAN", "Build with undefined-behavior sanitizer") orelse false;
    const MI_GUARDED = b.option(bool, "MI_GUARDED", "Build with guard pages behind allocations") orelse false;
    const MI_SKIP_COLLECT_ON_EXIT = b.option(bool, "MI_SKIP_COLLECT_ON_EXIT", "Skip collecting memory on program exit") orelse false;
    var MI_NO_PADDING = b.option(bool, "MI_NO_PADDING", "Force no use of padding") orelse false;
    //const MI_INSTALL_TOPLEVEL = b.option(bool, "MI_INSTALL_TOPLEVEL", "Install directly into prefix") orelse false;
    const MI_NO_THP = b.option(bool, "MI_NO_THP", "Disable transparent huge pages") orelse false;
    //const MI_EXTRA_CPPDEFS = b.option(std.ArrayList([]const u8), "MI_EXTRA_CPPDEFS", "Extra pre-processor definitions", std.ArrayList([]const u8).init(b.allocator));

    const MI_NO_USE_CXX = b.option(bool, "MI_NO_USE_CXX", "Use plain C compilation") orelse false;
    const MI_NO_OPT_ARCH = b.option(bool, "MI_NO_OPT_ARCH", "Do not use architecture specific optimizations") orelse false;

    const MI_WIN_USE_FLS = b.option(bool, "MI_WIN_USE_FLS", "Use Fiber local storage on Windows") orelse false;
    const MI_CHECK_FULL = b.option(bool, "MI_CHECK_FULL", "Use full internal invariant checking in DEBUG mode") orelse false;
    //const MI_USE_LIBATOMIC = b.option(bool, "MI_USE_LIBATOMIC", "Explicitly link with -latomic") orelse false;
    //
    //TODO: I hate this. Make these consts again -bcflock (for bcflock)
    //
    // Process Options
    if (MI_NO_USE_CXX) {
        MI_USE_CXX = false;
    }
    if (MI_NO_OPT_ARCH) {
        MI_OPT_ARCH = false;
    }

    if (builtin.target.os.tag == .windows) {
        MI_USE_CXX = true;
    }

    //TODO: gotta check all release options? this was originally just .Release
    if (optimize == .ReleaseSafe or optimize == .Debug) {
        if (!MI_OPT_ARCH) {
            std.debug.print("Architecture specific optimizations are disabled (MI_OPT_ARCH=OFF)\n", .{});
        }
    } else {
        MI_OPT_ARCH = false;
    }

    if (MI_OVERRIDE) {
        std.debug.print("Override standard malloc (MI_OVERRIDE=ON)\n", .{});
        if (builtin.target.os.tag == .macos) {
            if (MI_OSX_ZONE) {
                std.debug.print("  Use malloc zone to override malloc (MI_OSX_ZONE=ON)\n", .{});
                mi_sources.append("src/prim/osx/alloc-override-zone.c") catch return;
                mi_defines.append("MI_OSX_ZONE=1") catch return;
                if (!MI_OSX_INTERPOSE) {
                    std.debug.print("  WARNING: zone overriding usually also needs interpose (use -DMI_OSX_INTERPOSE=ON)\n", .{});
                }
            }
            if (MI_OSX_INTERPOSE) {
                std.debug.print("  Use interpose to override malloc (MI_OSX_INTERPOSE=ON)\n", .{});
                mi_defines.append("MI_OSX_INTERPOSE=1") catch return;
                if (!MI_OSX_ZONE) {
                    std.debug.print("  WARNING: interpose usually also needs zone overriding (use -DMI_OSX_INTERPOSE=ON)\n", .{});
                }
            }
            if (MI_USE_CXX and MI_OSX_INTERPOSE) {
                std.debug.print("  WARNING: if dynamically overriding malloc/free, it is more reliable to build mimalloc as C code (use -DMI_USE_CXX=OFF)\n", .{});
            }
        }
    }

    if (builtin.target.os.tag == .windows) {
        if (!MI_WIN_REDIRECT) {
            mi_defines.append("MI_WIN_NOREDIRECT=1") catch return;
        }
    }

    if (MI_SECURE) {
        std.debug.print("Set full secure build (MI_SECURE=ON)\n", .{});
        mi_defines.append("MI_SECURE=4") catch return;
    }

    if (MI_TRACK_VALGRIND) {
        // TODO: check for valgrind headers
        std.debug.print("Compile with Valgrind support (MI_TRACK_VALGRIND=ON)\n", .{});
        mi_defines.append("MI_TRACK_VALGRIND=1") catch return;
    }

    if (MI_TRACK_ASAN) {
        if (builtin.target.os.tag == .macos and MI_OVERRIDE) {
            MI_TRACK_ASAN = false;
            std.debug.print("Cannot enable address sanitizer support on macOS if MI_OVERRIDE is ON (MI_TRACK_ASAN=OFF)\n", .{});
        }
        if (MI_TRACK_VALGRIND) {
            MI_TRACK_ASAN = false;
            std.debug.print("Cannot enable address sanitizer support with also Valgrind support enabled (MI_TRACK_ASAN=OFF)\n", .{});
        }
        if (MI_TRACK_ASAN) {
            //TODO: check for asan headers
            std.debug.print("Compile with address sanitizer support (MI_TRACK_ASAN=ON)\n", .{});
            mi_defines.append("MI_TRACK_ASAN=1") catch return;
            mi_cflags.append("-fsanitize=address") catch return;
            mi_libraries.append("-fsanitize=address") catch return;
        }
    }

    if (MI_TRACK_ETW) {
        if (builtin.target.os.tag != .windows) {
            MI_TRACK_ETW = false;
            std.debug.print("Can only enable ETW support on Windows (MI_TRACK_ETW=OFF)\n", .{});
        }
        if (MI_TRACK_VALGRIND or MI_TRACK_ASAN) {
            MI_TRACK_ETW = false;
            std.debug.print("Cannot enable ETW support with also Valgrind or ASAN support enabled (MI_TRACK_ETW=OFF)\n", .{});
        }
        if (MI_TRACK_ETW) {
            std.debug.print("Compile with Windows event tracing support (MI_TRACK_ETW=ON)\n", .{});
            mi_defines.append("MI_TRACK_ETW=1") catch return;
        }
    }

    if (MI_GUARDED) {
        std.debug.print("Compile guard pages behind certain object allocations (MI_GUARDED=ON)\n", .{});
        mi_defines.append("MI_GUARDED=1") catch return;
        if (!MI_NO_PADDING) {
            std.debug.print("  Disabling padding due to guard pages (MI_NO_PADDING=ON)\n", .{});
            MI_NO_PADDING = true;
        }
    }

    if (MI_SEE_ASM) {
        std.debug.print("Generate assembly listings (MI_SEE_ASM=ON)\n", .{});
        mi_cflags.append("-save-temps") catch return;
        if (true) {
            std.debug.print("No GNU Line marker\n", .{});
            mi_cflags.append("-Wno-gnu-line-marker") catch return;
        }
    }

    if (MI_CHECK_FULL) {
        std.debug.print("The MI_CHECK_FULL option is deprecated, use MI_DEBUG_FULL instead\n", .{});
        MI_DEBUG_FULL = true;
    }

    if (MI_SKIP_COLLECT_ON_EXIT) {
        std.debug.print("Skip collecting memory on program exit (MI_SKIP_COLLECT_ON_EXIT=ON)\n", .{});
        mi_defines.append("MI_SKIP_COLLECT_ON_EXIT=1") catch return;
    }

    if (MI_DEBUG_FULL) {
        std.debug.print("Set debug level to full internal invariant checking (MI_DEBUG_FULL=ON)\n", .{});
        mi_defines.append("MI_DEBUG=3") catch return;
    }

    if (MI_NO_PADDING) {
        std.debug.print("Suppress any padding of heap blocks (MI_NO_PADDING=ON)\n", .{});
        mi_defines.append("MI_PADDING=0") catch return;
    } else {
        if (MI_PADDING) {
            std.debug.print("Enable explicit padding of heap blocks (MI_PADDING=ON)\n", .{});
            mi_defines.append("MI_PADDING=1") catch return;
        }
    }

    if (MI_XMALLOC) {
        std.debug.print("Enable abort() calls on memory allocation failure (MI_XMALLOC=ON)\n", .{});
        mi_defines.append("MI_XMALLOC=1") catch return;
    }

    if (MI_SHOW_ERRORS) {
        std.debug.print("Enable printing of error and warning messages by default (MI_SHOW_ERRORS=ON)\n", .{});
        mi_defines.append("MI_SHOW_ERRORS=1") catch return;
    }

    if (MI_DEBUG_TSAN) {
        if (true) { //(target.compiles_with.clang) {
            std.debug.print("Build with thread sanitizer (MI_DEBUG_TSAN=ON)\n", .{});
            mi_defines.append("MI_TSAN=1") catch return;
            mi_cflags.append("-fsanitize=thread") catch return;
            mi_cflags.append("-g") catch return;
            mi_cflags.append("-O1") catch return;
            mi_libraries.append("-fsanitize=thread") catch return;
        } else {
            std.debug.print("Can only use thread sanitizer with clang (MI_DEBUG_TSAN=ON but ignored)\n", .{});
        }
    }

    if (MI_DEBUG_UBSAN) {
        if (optimize == .Debug) {
            std.debug.print("Can only use undefined-behavior sanitizer with clang++ (MI_DEBUG_UBSAN=ON but ignored)\n", .{});
        } else {
            std.debug.print("Can only use undefined-behavior sanitizer with a debug build (CMAKE_BUILD_TYPE={s})\n", .{std.enums.tagName(std.builtin.OptimizeMode, optimize) orelse ""});
        }
    }

    if (MI_USE_CXX) {
        std.debug.print("Use the C++ compiler to compile (MI_USE_CXX=ON)\n", .{});
        // TODO: set source file properties to C++
        mi_cflags.append("-Wno-deprecated") catch return;
    }

    if (builtin.target.os.tag == .linux or builtin.target.os.tag == .android) {
        if (MI_NO_THP) {
            std.debug.print("Disable transparent huge pages support (MI_NO_THP=ON)\n", .{});
            mi_defines.append("MI_NO_THP=1") catch return;
        }
    }

    if (MI_LIBC_MUSL) {
        std.debug.print("Assume using musl libc (MI_LIBC_MUSL=ON)\n", .{});
        mi_defines.append("MI_LIBC_MUSL=1") catch return;
    }

    if (MI_WIN_USE_FLS) {
        std.debug.print("Use the Fiber API to detect thread termination (deprecated) (MI_WIN_USE_FLS=ON)\n", .{});
        mi_defines.append("MI_WIN_USE_FLS=1") catch return;
    }

    if (MI_WIN_USE_FIXED_TLS) {
        std.debug.print("Use fixed TLS slot on Windows to avoid extra tests in the malloc fast path (MI_WIN_USE_FIXED_TLS=ON)\n", .{});
        mi_defines.append("MI_WIN_USE_FIXED_TLS=1") catch return;
    }

    // Determine architecture
    var MI_OPT_ARCH_FLAGS: std.ArrayList([]const u8) = std.ArrayList([]const u8).init(b.allocator);
    defer MI_OPT_ARCH_FLAGS.deinit();

    var MI_ARCH: []const u8 = "unknown";
    if (builtin.target.cpu.arch == .x86) {
        MI_ARCH = "x86";
    } else if (builtin.target.cpu.arch == .x86_64) {
        MI_ARCH = "x64";
    } else if (builtin.target.cpu.arch == .aarch64) {
        MI_ARCH = "arm64";
    } else if (builtin.target.cpu.arch == .arm) {
        MI_ARCH = "arm32";
    } else if (builtin.target.cpu.arch == .riscv32) {
        MI_ARCH = "riscv32";
    } else if (builtin.target.cpu.arch == .riscv64) {
        MI_ARCH = "riscv64";
    } else {
        MI_ARCH = builtin.target.cpu.arch.getName();
    }
    std.debug.print("Architecture: {s}\n", .{MI_ARCH});

    // Compiler flags
    mi_cflags.append("-Wno-unknown-pragmas") catch return;
    mi_cflags.append("-fvisibility=hidden") catch return;
    if (!MI_USE_CXX) {
        mi_cflags.append("-Wstrict-prototypes") catch return;
    }
    mi_cflags.append("-Wno-static-in-inline") catch return;

    if (builtin.target.os.tag != .haiku) {
        if (MI_LOCAL_DYNAMIC_TLS) {
            mi_cflags.append("-ftls-model=local-dynamic") catch return;
        } else {
            if (MI_LIBC_MUSL) {
                mi_cflags_static.append("-ftls-model=local-dynamic") catch return;
                mi_cflags_dynamic.append("-ftls-model=initial-exec") catch return;
                std.debug.print("Use local dynamic TLS for the static build (since MI_LIBC_MUSL=ON)\n", .{});
            } else {
                mi_cflags.append("-ftls-model=initial-exec") catch return;
            }
        }
        if (MI_OVERRIDE) {
            mi_cflags.append("-fno-builtin-malloc") catch return;
        }
    }

    if (builtin.target.os.tag != .haiku) {
        if (MI_OPT_ARCH) {
            if (builtin.target.os.tag == .macos and target.compiles_with.apple_clang and builtin.target.os.arch_list) { // TODO: implement target.os.arch_list
                MI_OPT_ARCH_FLAGS.clearRetainingCapacity();
                if (std.mem.indexOf(builtin.target.os.arch_list, "arm64")) { //TODO: implement mem.indexOf
                    MI_OPT_ARCH_FLAGS.append("-Xarch_arm64") catch return;
                    MI_OPT_ARCH_FLAGS.append("-march=armv8.1-a") catch return;
                }
            } else if (std.mem.eql(u8, MI_ARCH, "arm64")) {
                MI_OPT_ARCH_FLAGS.append("-march=armv8.1-a") catch return;
            }
        }
    }

    if (builtin.target.os.tag == .windows and target.abi == .gnu) { // MINGW
        mi_defines.append("_WIN32_WINNT=0x601") catch return;
    }

    if (MI_OPT_ARCH_FLAGS.items.len > 0) {
        for (MI_OPT_ARCH_FLAGS.items) |flag| {
            mi_cflags.append(flag) catch return;
        }
        std.debug.print("Architecture specific optimization is enabled (with {s}) (MI_OPT_ARCH=ON)\n", .{std.mem.join(b.allocator, " ", MI_OPT_ARCH_FLAGS.items) catch unreachable});
    }

    // extra needed libraries
    if (builtin.target.os.tag == .windows) {
        mi_libraries.append("psapi") catch return;
        mi_libraries.append("shell32") catch return;
        mi_libraries.append("user32") catch return;
        mi_libraries.append("advapi32") catch return;
        mi_libraries.append("bcrypt") catch return;
    } else {
        mi_libraries.append("pthread") catch return;
        mi_libraries.append("rt") catch return;
        mi_libraries.append("atomic") catch return;
    }

    // Install and output names
    const mi_libname = if (MI_SECURE) "mimalloc-secure" else "mimalloc";
    const mi_libname_asan = std.fmt.allocPrint(b.allocator, "{s}{s}", .{ mi_libname, if (MI_TRACK_ASAN) "-asan" else "" }) catch return;
    const mi_libname_valgrind = std.fmt.allocPrint(b.allocator, "{s}{s}", .{ mi_libname_asan, if (MI_TRACK_VALGRIND) "-valgrind" else "" }) catch return;
    const mi_libname_build_type = std.fmt.allocPrint(b.allocator, "{s}{s}", .{ mi_libname_valgrind, if (optimize != .ReleaseSafe and optimize != .Debug and optimize != .ReleaseSmall) std.enums.tagName(std.builtin.OptimizeMode, optimize) orelse "" else "" }) catch return;

    var mi_build_targets: std.ArrayList([]const u8) = std.ArrayList([]const u8).init(b.allocator);
    defer mi_build_targets.deinit();

    if (MI_BUILD_SHARED) {
        mi_build_targets.append("shared") catch return;
    }
    if (MI_BUILD_STATIC) {
        mi_build_targets.append("static") catch return;
    }
    if (MI_BUILD_OBJECT) {
        mi_build_targets.append("object") catch return;
    }
    if (MI_BUILD_TESTS) {
        mi_build_targets.append("tests") catch return;
    }

    std.debug.print("\n", .{});
    std.debug.print("Library name     : {s}\n", .{mi_libname_build_type});
    std.debug.print("Version          : {s}.{s}\n", .{ mi_version, mi_version_patch });
    std.debug.print("Build type       : {s}\n", .{std.enums.tagName(std.builtin.OptimizeMode, optimize) orelse ""});
    std.debug.print("{s} Compiler       : {s}\n", .{ if (MI_USE_CXX) "C++" else "C", "TODO: Find command for find zig exe" });
    std.debug.print("Compiler flags   : {s}\n", .{std.mem.join(b.allocator, " ", mi_cflags.items) catch unreachable});
    std.debug.print("Link libraries   : {s}\n", .{std.mem.join(b.allocator, " ", mi_libraries.items) catch unreachable});
    std.debug.print("Build targets    : {s}\n", .{std.mem.join(b.allocator, " ", mi_build_targets.items) catch unreachable});
    std.debug.print("\n", .{});

    // Main targets
    if (MI_BUILD_SHARED) {
        var cflags = std.ArrayList([]const u8).init(b.allocator);
        defer cflags.deinit();
        const shared_lib = b.addSharedLibrary(.{
            .name = "mimalloc",
            .target = target,
            .optimize = optimize,
        });
        shared_lib.addIncludePath(b.path("include"));
        shared_lib.addIncludePath(b.path("include/mimalloc"));
        for (mi_cflags.items) |item| {
            cflags.append(item) catch return;
        }
        for (mi_cflags_dynamic.items) |item| {
            cflags.append(item) catch return;
        }
        for (mi_libraries.items) |lib_name| {
            shared_lib.linkSystemLibrary(lib_name);
        }
        shared_lib.linkLibC();

        shared_lib.addCSourceFiles(.{ .files = &mi_sources, .flags = cflags.items, .root = b.path(".") });

        b.installArtifact(shared_lib);

        if (builtin.target.os.tag == .windows) {
            shared_lib.setLinkerScriptFlags(&[_][]const u8{
                "-Wl,--out-implib,mimalloc.dll.lib",
            });

            shared_lib.root_module.addCMacro("__TIME__", "\"T\"");
            shared_lib.root_module.addCMacro("__DATE__", "\"D\"");
            //TODO: def need to figure out what this is
            //
            //b.installFile("mimalloc.dll.lib", "lib");

            if (MI_WIN_REDIRECT) {
                var MIMALLOC_REDIRECT_SUFFIX: []const u8 = undefined;
                if (builtin.target.cpu.arch == .aarch64 and builtin.target.os.arch_list and std.mem.indexOf(builtin.target.os.arch_list, "arm64ec")) {
                    MIMALLOC_REDIRECT_SUFFIX = "-arm64ec";
                } else if (builtin.target.cpu.arch == .x86_64) {
                    MIMALLOC_REDIRECT_SUFFIX = "";
                    if (builtin.target.cpu.arch == .aarch64) {
                        std.debug.print("Note: x64 code emulated on Windows for arm64 should use an arm64ec build of 'mimalloc.dll'\n", .{});
                        std.debug.print("      together with 'mimalloc-redirect-arm64ec.dll'. See the 'bin\\readme.md' for more information.\n", .{});
                    }
                } else if (builtin.target.cpu.arch == .x86) {
                    MIMALLOC_REDIRECT_SUFFIX = "32";
                } else {
                    MIMALLOC_REDIRECT_SUFFIX = std.fmt.allocPrint(b.allocator, "-{s}", .{MI_ARCH}) catch unreachable;
                }

                const redirect_lib = std.fmt.allocPrint(b.allocator, "bin/mimalloc-redirect{s}.lib", .{MIMALLOC_REDIRECT_SUFFIX}) catch unreachable;
                shared_lib.addSharedObject(redirect_lib);
                //const redirect_dll = std.fmt.allocPrint(b.allocator, "bin/mimalloc-redirect{s}.dll", .{MIMALLOC_REDIRECT_SUFFIX}) catch unreachable;
                shared_lib.linkLibC();
                b.installArtifact(shared_lib);
                //b.installFile(redirect_dll, "bin");
            }
        }
    }

    if (MI_BUILD_STATIC) {
        const static_lib = b.addStaticLibrary(.{ .name = "mimalloc-static", .target = target, .optimize = optimize });
        //static_lib.root_module.addCMacro("__TIME__", "\"T\"");
        //static_lib.root_module.addCMacro("__DATE__", "\"D\"");
        static_lib.addIncludePath(b.path("include"));
        var cflags = std.ArrayList([]const u8).init(b.allocator);
        defer cflags.deinit();
        for (mi_cflags.items) |item| {
            cflags.append(item) catch return;
        }
        for (mi_cflags_static.items) |item| {
            cflags.append(item) catch return;
        }
        for (mi_libraries.items) |lib_name| {
            static_lib.linkSystemLibrary(lib_name);
        }
        static_lib.linkLibC();
        static_lib.addCSourceFiles(.{
            .files = &mi_sources,
            .flags = cflags.items,
            .root = b.path("."),
        });
        b.installArtifact(static_lib);
    }

    // install include files
    //b.installFile("include/mimalloc.h", "include");
    //    b.installFile("include/mimalloc-override.h", "include");
    //    b.installFile("include/mimalloc-new-delete.h", "include");

    // object file
    if (MI_BUILD_OBJECT) {
        const obj_lib = b.addSharedLibrary(.{ .name = "mimalloc-obj", .target = target, .optimize = optimize });
        obj_lib.root_module.addCMacro("__TIME__", "\"T\"");
        obj_lib.root_module.addCMacro("__DATE__", "\"D\"");
        obj_lib.addIncludePath(b.path("include"));
        var cflags = std.ArrayList([]const u8).init(b.allocator);
        defer cflags.deinit();
        for (mi_cflags.items) |flag| {
            cflags.append(flag) catch return;
        }
        for (mi_cflags_static.items) |flag| {
            cflags.append(flag) catch return;
        }
        obj_lib.linkLibC();
        obj_lib.addCSourceFile(.{ .flags = cflags.items, .file = b.path("src/static.c") });
    }

    //tests
    if (MI_BUILD_TESTS) {
        const test_step = b.step("test", "Run tests");
        const test_names = [_][]const u8{ "api", "api-fill", "stress" };
        for (test_names) |test_name| {
            var cflags = std.ArrayList([]const u8).init(b.allocator);
            defer cflags.deinit();
            const exe_source: []const u8 = std.fmt.allocPrint(b.allocator, "test/test-{s}.c", .{test_name}) catch unreachable;
            const exe = b.addExecutable(.{ .name = std.fmt.allocPrint(b.allocator, "mimalloc-test-{s}", .{test_name}) catch unreachable, .target = target, .optimize = optimize });
            exe.addIncludePath(b.path("include"));
            exe.addCSourceFile(.{ .file = b.path(exe_source), .flags = cflags.items });
            for (mi_cflags.items) |flag| {
                cflags.append(flag) catch return;
            }

            exe.addLibraryPath(b.path("zig-out/lib"));
            if (MI_BUILD_SHARED and (MI_TRACK_ASAN or MI_DEBUG_TSAN) or MI_DEBUG_UBSAN) {
                exe.linkSystemLibrary("mimalloc");
            } else {
                exe.linkSystemLibrary("mimalloc-static");
            }

            for (mi_libraries.items) |lib_name| {
                exe.linkSystemLibrary(lib_name);
            }
            exe.linkLibC();

            const run_cmd = b.addRunArtifact(exe);
            const test_step_exe = b.step(std.fmt.allocPrint(b.allocator, "test-{s}", .{test_name}) catch unreachable, "Run Test");
            test_step.dependOn(&run_cmd.step);
            _ = test_step_exe;
        }

        if (MI_BUILD_SHARED and !(MI_TRACK_ASAN or MI_DEBUG_TSAN) or MI_DEBUG_UBSAN) {
            var cflags = std.ArrayList([]const u8).init(b.allocator);
            defer cflags.deinit();
            const exe = b.addExecutable(.{ .name = "mimalloc-test-stress-dynamic", .target = target, .optimize = optimize });
            exe.addCSourceFile(.{ .file = b.path("test/test-stress.c"), .flags = cflags.items });
            exe.addIncludePath(b.path("include"));

            exe.addLibraryPath(b.path("zig-out/lib"));
            exe.linkSystemLibrary("mimalloc");
            exe.linkSystemLibrary("mimalloc-static");
            for (mi_libraries.items) |lib_name| {
                exe.linkSystemLibrary(lib_name);
            }

            exe.linkLibC();
            const run_cmd = b.addRunArtifact(exe);
            test_step.dependOn(&run_cmd.step);
        }
    }

    //override properties
    if (MI_OVERRIDE) {
        if (builtin.target.os.tag != .windows) {
            if (MI_BUILD_STATIC) {
                const static_lib = b.addStaticLibrary(.{ .name = "mimalloc-static", .target = target, .optimize = optimize });
                static_lib.addIncludePath(b.path("include"));
                var cflags = std.ArrayList([]const u8).init(b.allocator);
                defer cflags.deinit();
                for (mi_cflags.items) |flag| {
                    cflags.append(flag) catch return;
                }
                for (mi_cflags_static.items) |flag| {
                    cflags.append(flag) catch return;
                }
                static_lib.addCSourceFiles(.{ .files = &mi_sources, .root = b.path("."), .flags = cflags.items });
                for (mi_libraries.items) |lib_name| {
                    static_lib.linkSystemLibrary(lib_name);
                }
                b.installArtifact(static_lib);
            }
            if (MI_BUILD_OBJECT) {
                const obj_lib = b.addStaticLibrary(.{ .name = "mimalloc-obj", .target = target, .optimize = optimize });
                obj_lib.addIncludePath(b.path("include"));
                var cflags = std.ArrayList([]const u8).init(b.allocator);
                defer cflags.deinit();
                for (mi_cflags.items) |flag| {
                    cflags.append(flag) catch return;
                }
                for (mi_cflags_static.items) |flag| {
                    cflags.append(flag) catch return;
                }
                obj_lib.addCSourceFile(.{ .file = b.path("src/static.c"), .flags = cflags.items });
                obj_lib.linkLibC();
                b.installArtifact(obj_lib);
            }
        }
    }
}
