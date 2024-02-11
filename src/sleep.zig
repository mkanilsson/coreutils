const clap = @import("clap");
const std = @import("std");

const CLI = @import("helpers/cli.zig").CLI;

const io = std.io;
const process = std.process;

// Globals
const description = "Sleep for the specified time";

const params = clap.parseParamsComptime(
    \\-h, --help           Display this help and exit.
    \\<SECONDS>            Amount of seconds to sleep for.
    \\
);

const parsers = .{
    .SECONDS = clap.parsers.float(f64),
};

const cli = CLI(&params, parsers, description);

var line_number: usize = 1;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var res = try cli.getCommandLineArguments(allocator);
    defer res.deinit();

    std.time.sleep(@intFromFloat(res.positionals[0] * std.time.ns_per_s));
}
