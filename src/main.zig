const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const Dir = std.fs.Dir;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    const progName = args.next().?;
    std.log.info("cwd was: {s}", .{ .progName = progName });

    const cwd1 = try std.process.getCwdAlloc(allocator);
    defer allocator.free(cwd1);
    std.log.info("cwd was: {s}", .{ .cwd = cwd1 });

    const possibleCommand = args.next();

    if (possibleCommand) |cmd| {
        _ = cmd;
    }

    const tmp = try checkIfInZitRepo(allocator);

    if (!tmp) {
        std.log.info("Not in a Zit dir. \n", .{});
    } else {
        std.log.info("In a Zit dir. \n", .{});
    }
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

test "isInZitRepo isnt leaking" {
    const isInZitRepo = try checkIfInZitRepo(std.testing.allocator);
    try std.testing.expectEqual(isInZitRepo, isInZitRepo);
}
