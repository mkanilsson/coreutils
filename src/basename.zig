const clap = @import("clap");
const std = @import("std");

const CLI = @import("shared/cli.zig").CLI;
const DefaultAllocator = @import("shared/mem.zig").DefaultAllocator;

const debug = std.debug;
const io = std.io;
const process = std.process;

// Globals
const description = "Prints NAME with any leading directory components removed. If specified, also remove a trailing SUFFIX";

const params = clap.parseParamsComptime(
    \\-h, --help           Display this help and exit.
    \\<STRING>             A pathname.
    \\<SUFFIX>             Suffix to be removed from NAME.
    \\
);

const parsers = .{
    .STRING = clap.parsers.string,
    .SUFFIX = clap.parsers.string,
};

const cli = CLI(&params, parsers, description);

pub fn main() !void {
    var default_allocator = DefaultAllocator;
    defer _ = default_allocator.deinit();
    var allocator = default_allocator.allocator();

    var res = try cli.getCommandLineArguments(allocator);
    defer res.deinit();

    var stdout = io.getStdOut().writer();
    var stderr = io.getStdErr().writer();

    if (res.positionals.len < 1) {
        try cli.printUsageAndHelp(allocator, stderr, "Missing pathname");
        return process.exit(1);
    }

    if (res.positionals.len > 2) {
        try cli.printUsageAndHelp(allocator, stderr, "Too many arguments");
        return process.exit(1);
    }

    var suffix: ?[]const u8 = null;
    if (res.positionals.len == 2)
        suffix = res.positionals[1];

    try stdout.print("{s}\n", .{try getBasename(allocator, res.positionals[0], suffix)});
}

fn getBasename(allocator: std.mem.Allocator, path: []const u8, maybe_suffix: ?[]const u8) ![]const u8 {
    var valid_parts = std.ArrayList([]const u8).init(allocator);
    defer valid_parts.deinit();

    var parts = std.mem.split(u8, path, "/");
    while (parts.next()) |part| {
        if (!std.mem.eql(u8, part, "")) {
            try valid_parts.append(part);
        }
    }

    if (valid_parts.items.len == 0) {
        return "/";
    }

    const basename = valid_parts.getLast();

    if (maybe_suffix) |suffix| {
        if (!std.mem.eql(u8, basename, suffix)) {
            if (endsWith(basename, suffix)) {
                return basename[0 .. basename.len - suffix.len];
            }
        }
    }

    return basename;
}

fn endsWith(haystack: []const u8, needle: []const u8) bool {
    if (std.mem.indexOf(u8, haystack, needle)) |index| {
        if (index + needle.len == haystack.len) return true;
    }

    return false;
}
