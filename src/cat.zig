const clap = @import("clap");
const std = @import("std");

const CLI = @import("helpers/cli.zig").CLI;

const io = std.io;
const process = std.process;

// Globals
const description = "Concatenate files to stdout";

const params = clap.parseParamsComptime(
    \\-h, --help           Display this help and exit.
    \\-n, --number         Show line numbers.
    \\-E, --show-ends      Display $ at the end of each line.
    \\<FILE>               Path to file, if omitted, stdin will be used
    \\
);

const parsers = .{
    .INT = clap.parsers.int(usize, 10),
    .FILE = clap.parsers.string,
};

const cli = CLI(&params, parsers, description);

var line_number: usize = 1;

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

    const show_line_numbers = res.args.number != 0;
    const show_ends = res.args.@"show-ends" != 0;

    if (res.positionals.len == 0) {
        try printFile(io.getStdIn().reader(), stdout, show_line_numbers, show_ends);
    } else {
        for (res.positionals) |file_path| {
            if (std.mem.eql(u8, file_path, "-")) {
                try printFile(io.getStdIn().reader(), stdout, show_line_numbers, show_ends);
            } else {
                var file = try std.fs.cwd().openFile(file_path, .{});
                defer file.close();

                try printFile(file.reader(), stdout, show_line_numbers, show_ends);
            }
        }
    }
}

fn printFile(in_stream: anytype, out_stream: anytype, show_line_numbers: bool, show_ends: bool) !void {
    var buf_reader = std.io.bufferedReader(in_stream);
    var buf_in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;

    while (try buf_in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (show_line_numbers)
            try out_stream.print("{d: >6}  ", .{line_number});
        try out_stream.print("{s}", .{line});

        try out_stream.print("{s}\n", .{if (show_ends)
            "$"
        else
            ""});

        line_number += 1;
    }
}
