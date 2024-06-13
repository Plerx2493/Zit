const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const Dir = std.fs.Dir;
const Zit = @import("Zit.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    const progName = args.next().?;
    std.log.info("binpath was: {s}", .{ .progName = progName });

    const cwd = try std.process.getCwdAlloc(allocator);
    defer allocator.free(cwd);
    std.log.info("cwd was: {s}", .{ .cwd = cwd });

    const possibleCommand = args.next();

    if (possibleCommand == null) {
        showHelp();
        return;
    }

    const isRepo = try Zit.checkIfInRepo(allocator);

    if (std.mem.eql(u8, possibleCommand.?, "init")) {
        if (isRepo) {
            std.log.err("Already a Zit repo", .{});
            return;
        }

        if (!try Zit.initRepo()) {
            std.log.err("Init repo failed", .{});
        }

        return;
    }
}

pub fn showHelp() void {
    std.log.info("Zit was invoked without any param or the command could not infered!\nCurently available commands:\n\t- init\t\tinitilize the current folder as a zit repo", .{});
}
