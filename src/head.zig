const clap = @import("clap");
const std = @import("std");

const CLI = @import("helpers/cli.zig").CLI;

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

    var lines = res.args.lines orelse 10;
    const stdin = io.getStdIn().reader();

    if (res.positionals.len == 0) {
        try printHead(allocator, stdin, lines);
    } else {
        var file_path = res.positionals[0];
        var file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        try printHead(allocator, file.reader(), lines);
    }
}

fn printHead(allocator: std.mem.Allocator, reader: anytype, lines: usize) !void {
    var buf_reader = std.io.bufferedReader(reader);
    var in_stream = buf_reader.reader();

    var lines_read: usize = 0;
    while (true) {
        var line = std.ArrayList(u8).init(allocator);
        defer line.deinit();

        in_stream.streamUntilDelimiter(line.writer(), '\n', null) catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };

        if (lines_read == lines)
            break;

        const line_slice = try line.toOwnedSlice();
        defer allocator.free(line_slice);

        try io.getStdOut().writer().print("{s}\n", .{line_slice});
        lines_read += 1;
    }
}
