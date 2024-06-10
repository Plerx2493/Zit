const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const Dir = std.fs.Dir;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    while (args.next()) |arg| {
        std.log.info("arg was: {}", arg);
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const tmp = try checkIfInZitRepo(allocator);

    if (!tmp) {
        try stdout.print("Not in a Zit dir. \n", .{});
    } else {
        try stdout.print("In a Zit dir. \n", .{});
    }

    try bw.flush();
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

test "isInZitRepo isnt leaking" {
    const isInZitRepo = try checkIfInZitRepo(std.testing.allocator);
    try std.testing.expectEqual(isInZitRepo, isInZitRepo);
}
