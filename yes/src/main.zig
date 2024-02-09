const clap = @import("clap");
const std = @import("std");

const debug = std.debug;
const io = std.io;
const process = std.process;

// Globals
const description = "Repeatedly prints \"yes\" (or OPTION) indefinently";

const params = clap.parseParamsComptime(
    \\-h, --help           Display this help and exit.
    \\<OPTION>...          Alternative string
    \\
);

const parsers = .{
    .OPTION = clap.parsers.string,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var res = try getCommandLineArguments(allocator);
    defer res.deinit();

    var stdout = io.getStdOut().writer();
    var stderr = io.getStdErr().writer();

    if (res.args.help != 0) {
        try printUsageAndHelp(allocator, stderr, null);
        return process.exit(0);
    }

    var message = if (res.positionals.len > 0) blk: {
        var current: ?[]u8 = null;

        for (res.positionals) |value| {
            if (current) |c| {
                var new = try std.fmt.allocPrint(allocator, "{s} {s}", .{ c, value });
                allocator.free(c);
                current = new;
            } else {
                current = try std.fmt.allocPrint(allocator, "{s}", .{value});
            }
        }
        break :blk current;
    } else null;

    defer if (message) |msg| allocator.free(msg);

    while (true) {
        if (message) |msg| {
            try stdout.print("{s}\n", .{msg});
        } else {
            try stdout.print("y\n", .{});
        }
    }
}

fn getCommandLineArguments(allocator: std.mem.Allocator) !clap.Result(clap.Help, &params, parsers) {
    var diagnostic = clap.Diagnostic{};

    var res = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diagnostic,
        .allocator = allocator,
    }) catch |err| {
        diagnostic.report(io.getStdErr().writer(), err) catch {};
        return err;
    };

    return res;
}

fn printUsageAndHelp(allocator: std.mem.Allocator, stream: anytype, message: ?[]const u8) !void {
    const args = try process.argsAlloc(allocator);
    defer process.argsFree(allocator, args);
    var program = args[0];

    if (message) |msg| {
        try stream.print("{s}\n", .{msg});
    }

    try stream.print("Usage: {s} ", .{program});
    try clap.usage(stream, clap.Help, &params);
    try stream.print("\n{s}\n", .{description});
    try clap.help(stream, clap.Help, &params, .{});
}
