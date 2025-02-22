const std = @import("std");
//const mim = @import("libmimalloc");
const c = @cImport({
    @cInclude("mimalloc.h");
});

pub fn main() void {
    _ = c;
    const n = 10;
    const result = c.mi_malloc(n * @sizeOf(i8));
    var arr : []i8 = @as([*]i8, @ptrCast(result))[0..10];
    defer c.mi_free(result);


    //if (arr == null){

    //}

    for (0..10) |i| {
        arr[i] = @as(i8, @intCast(i)) * 10;
    }

    std.debug.print("Memory allocated", .{});

    for (0.., arr) |i, val| {
        std.debug.print("{d}: {d}\n", .{i, val});
    }

}
