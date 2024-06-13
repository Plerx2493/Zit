const std = @import("std");
const Allocator = std.mem.Allocator;
const fs = std.fs;

const ZitVersion = "v0.1.0";

const Repository = struct {
    path: []u8,
    branches: [][]u8,
};

pub fn parseRepo(path: []u8) Repository {
    return Repository{ .path = path };
}

pub fn initRepo() !bool {
    std.log.info("parsed command \"init\"", .{});
    fs.cwd().makeDir(".zit") catch return false;
    const zitDir = fs.cwd().openDir(".zit", fs.Dir.OpenDirOptions{ .access_sub_paths = true, .iterate = true }) catch return false;

    const versionFile = zitDir.createFile("zitversion", fs.File.CreateFlags{}) catch return false;
    const bytesWritten = versionFile.write(ZitVersion) catch return false;
    if (bytesWritten != ZitVersion.len) return false;

    zitDir.makeDir("commits") catch return false;
    zitDir.makeDir("branches") catch return false;
    zitDir.makeDir("workingSet") catch return false;

    return true;
}

pub fn checkIfInRepo(allocator: Allocator) anyerror!bool {
    var currentDir = try fs.cwd().openDir(".", fs.Dir.OpenDirOptions{ .access_sub_paths = true, .iterate = true });

    while (!try isRootDir(currentDir, allocator)) {
        if (try dirContainsZitDir(currentDir)) {
            return true;
        }
        currentDir = try currentDir.openDir("../", fs.Dir.OpenDirOptions{ .access_sub_paths = true, .iterate = true });
    }
    return false;
}

fn isRootDir(dir: fs.Dir, allocator: Allocator) anyerror!bool {
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

fn dirContainsZitDir(dir: fs.Dir) anyerror!bool {
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
    const isInZitRepo = try checkIfInRepo(std.testing.allocator);
    try std.testing.expectEqual(isInZitRepo, isInZitRepo);
}
