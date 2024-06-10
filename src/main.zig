const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const Dir = std.fs.Dir;

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    //std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    //try stdout.print("Run `zig build test` to run the tests.\n", .{});
    const allocator = std.heap.page_allocator;
    const tmp = try checkIfInZitRepo(allocator);

    if (!tmp) {
        try stdout.print("Not in a Zit dir. \n", .{});
    } else {
        try stdout.print("In a Zit dir. \n", .{});
    }

    try bw.flush(); // don't forget to flush!
}

pub fn checkIfInZitRepo(allocator: Allocator) anyerror!bool {
    var currentDir = try fs.cwd().openDir(".", Dir.OpenDirOptions{ .access_sub_paths = true, .iterate = true });
    while (!try isRootDir(currentDir, allocator)) {
        if (try dirContainsZitDir(currentDir)) {
            return true;
        }
        currentDir = try currentDir.openDir("../", Dir.OpenDirOptions{ .access_sub_paths = true, .iterate = true });
    }
    return false;
}

fn isRootDir(dir: Dir, allocator: Allocator) anyerror!bool {
    const currentPath = try dir.realpathAlloc(allocator, ".");
    defer allocator.free(currentPath);

    // Check for Unix-like root "/"
    if (std.mem.eql(u8, currentPath, "/")) {
        return true;
    }

    // Check for Windows-like root "C:\" (adjust if necessary for multiple drives)
    if (currentPath.len == 3 and currentPath[1] == ':' and currentPath[2] == '\\') {
        return true;
    }

    return false;
}

fn isZitDir(path: []const u8) bool {
    if (std.mem.eql(u8, path, ".zit")) {
        return true;
    }

    return false;
}

fn dirContainsZitDir(dir: Dir) anyerror!bool {
    var iter = dir.iterate();

    while (try iter.next()) |entry| {
        if (entry.kind == std.fs.File.Kind.directory) {
            if (isZitDir(entry.name)) {
                return true;
            }
        }
    }
    return false;
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "isInZitRepo" {
    const isInZitRepo = try checkIfInZitRepo(std.testing.allocator);
    try std.testing.expectEqual(true, isInZitRepo);
}
