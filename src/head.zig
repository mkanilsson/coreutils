const clap = @import("clap");
const std = @import("std");

const CLI = @import("helpers/cli.zig").CLI;

const debug = std.debug;
const io = std.io;
const process = std.process;

// Globals
const description = "Show the n first lines of FILE";

const params = clap.parseParamsComptime(
    \\-h, --help           Display this help and exit.
    \\-n, --lines <INT>    Number of lines to print (default: 10).
    \\<FILE>               Path to file, if omitted, stdin will be used
    \\
);

const parsers = .{
    .INT = clap.parsers.int(usize, 10),
    .FILE = clap.parsers.string,
};

const cli = CLI(&params, parsers, description);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var res = try cli.getCommandLineArguments(allocator);
    defer res.deinit();

    var stdout = io.getStdOut().writer();

    var reader = if (res.positionals.len == 0) blk: {
        break :blk io.getStdIn().reader();
    } else blk: {
        var file_path = res.positionals[0];

        var file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        break :blk file.reader();
    };

    var lines = res.args.lines orelse 10;

    var buf_reader = std.io.bufferedReader(reader);
    var in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    var lines_read: usize = 0;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (lines_read == lines)
            break;

        try stdout.print("{s}\n", .{line});
        lines_read += 1;
    }
}
