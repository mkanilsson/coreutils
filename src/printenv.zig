const clap = @import("clap");
const std = @import("std");

const CLI = @import("helpers/cli.zig").CLI;

const io = std.io;
const process = std.process;

// Globals
const description = "Prints environment variables";

// TODO: Add null flag
//       \\-0, --null           End each output line with NULL instead of newline.
const params = clap.parseParamsComptime(
    \\-h, --help           Display this help and exit.
    \\<VARIABLES>          Variable which value will be printed.
    \\
);

const parsers = .{
    .VARIABLES = clap.parsers.string,
};

const cli = CLI(&params, parsers, description);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var res = try cli.getCommandLineArguments(allocator);
    defer res.deinit();

    var stdout = io.getStdOut().writer();
    var stderr = io.getStdErr().writer();

    if (res.args.help != 0) {
        try cli.printUsageAndHelp(allocator, stderr, null);
        return process.exit(0);
    }

    var envs = try process.getEnvMap(allocator);
    defer envs.deinit();

    if (res.positionals.len > 0) {
        for (res.positionals) |name| {
            if (envs.get(name)) |value| {
                try stdout.print("{s}\n", .{value});
            }
        }
    } else {
        var iterator = envs.iterator();

        while (iterator.next()) |env| {
            try stdout.print("{s}={s}\n", .{ env.key_ptr.*, env.value_ptr.* });
        }
    }
}
