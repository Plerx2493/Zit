const std = @import("std");
const Allocator = std.mem.Allocator;
const fs = std.fs;

const ZitVersion = "v0.1.0";

pub const Repository = struct {
    path: []u8,
    branches: ?[][]u8,
    version: []u8,

    pub fn parse(path: []u8, allocator: Allocator) !Repository {
        std.log.debug("Trying to parse zit repo at {s}", .{ .path = path });

        const zitDir = try fs.openDirAbsolute(path, fs.Dir.OpenDirOptions{ .access_sub_paths = true, .iterate = true });

        var iter = zitDir.iterate();

        var potentialVersion: ?[]u8 = null;

        while (try iter.next()) |entry| {
            if (entry.kind == std.fs.File.Kind.file and std.mem.eql(u8, entry.name, "zitversion")) {
                std.log.debug("Found zitversion", .{});
                const versionFile = try zitDir.openFile(entry.name, fs.File.OpenFlags{});
                defer versionFile.close();
                potentialVersion = try versionFile.readToEndAlloc(allocator, 1024);
            }

            if (entry.kind == fs.File.Kind.directory and std.mem.eql(u8, entry.name, "zitversion")) {}
        }

        return Repository{ .version = potentialVersion.?, .path = path, .branches = null };
    }
};

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

pub fn checkIfInRepo(allocator: Allocator) anyerror!?[]u8 {
    var currentDir = try fs.cwd().openDir(".", fs.Dir.OpenDirOptions{ .access_sub_paths = true, .iterate = true });

    while (!try isRootDir(currentDir, allocator)) {
        if (try dirContainsZitDir(currentDir)) {
            const zitDir = try currentDir.openDir(".zit", fs.Dir.OpenDirOptions{});
            return try zitDir.realpathAlloc(allocator, ".");
        }

        var oldDir = currentDir;
        currentDir = try oldDir.openDir("../", fs.Dir.OpenDirOptions{ .access_sub_paths = true, .iterate = true });
        oldDir.close();
    }
    return null;
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
