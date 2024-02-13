const clap = @import("clap");
const std = @import("std");

const CLI = @import("shared/cli.zig").CLI;

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

const cli = CLI(&params, parsers, description);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var res = try cli.getCommandLineArguments(allocator);
    defer res.deinit();

    var stdout = io.getStdOut().writer();

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
