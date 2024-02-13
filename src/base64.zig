const clap = @import("clap");
const std = @import("std");

const CLI = @import("shared/cli.zig").CLI;
const DefaultAllocator = @import("shared/mem.zig").DefaultAllocator;

const io = std.io;
const process = std.process;

// Globals
const description = "Base64 encde or decode FILE, or stdin, to stdout";

const params = clap.parseParamsComptime(
    \\-h, --help           Display this help and exit.
    \\-d, --decode         Decode data.
    \\<FILE>               Path to file, if omitted, stdin will be used
    \\
);

const parsers = .{
    .FILE = clap.parsers.string,
};

const cli = CLI(&params, parsers, description);

var line_number: usize = 1;

pub fn main() !void {
    var default_allocator = DefaultAllocator;
    defer _ = default_allocator.deinit();
    var allocator = default_allocator.allocator();

    var res = try cli.getCommandLineArguments(allocator);
    defer res.deinit();

    var stdout = io.getStdOut().writer();
    var stderr = io.getStdErr().writer();

    if (res.positionals.len > 1) {
        try cli.printUsageAndHelp(allocator, stderr, "Too many arguments");
        process.exit(1);
    }

    var decode = res.args.decode != 0;

    if (res.positionals.len == 0) {
        try printFile(allocator, io.getStdIn().reader(), stdout, decode);
    } else {
        var file_path = res.positionals[0];

        if (std.mem.eql(u8, file_path, "-")) {
            try printFile(allocator, io.getStdIn().reader(), stdout, decode);
        } else {
            var file = try std.fs.cwd().openFile(file_path, .{});
            defer file.close();

            try printFile(allocator, file.reader(), stdout, decode);
        }
    }
}

fn printFile(allocator: std.mem.Allocator, in_stream: anytype, out_stream: anytype, decode: bool) !void {
    var buf_reader = std.io.bufferedReader(in_stream);
    var buf_in_stream = buf_reader.reader();

    var data = std.ArrayList(u8).init(allocator);
    defer data.deinit();

    while (true) {
        buf_in_stream.streamUntilDelimiter(data.writer(), '\n', null) catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };

        _ = try data.writer().write("\n");
    }

    if (decode) {
        var decoder = std.base64.standard.Decoder;

        var data_slice = try data.toOwnedSlice();
        defer allocator.free(data_slice);

        var offset: u8 = 0;
        // Remove trailing newline if it exists
        if (data_slice[data_slice.len - 1] == '\n')
            offset = 1;

        var size = try decoder.calcSizeForSlice(data_slice[0 .. data_slice.len - offset]);
        var buffer = try allocator.alloc(u8, size);
        defer allocator.free(buffer);

        try decoder.decode(buffer, data_slice[0 .. data_slice.len - offset]);

        try out_stream.writeAll(buffer);
    } else {
        var encoder = std.base64.standard.Encoder;

        var size = encoder.calcSize(data.items.len);
        var buffer = try allocator.alloc(u8, size);
        defer allocator.free(buffer);

        var data_slice = try data.toOwnedSlice();
        defer allocator.free(data_slice);

        _ = encoder.encode(buffer, data_slice);
        try out_stream.writeAll(buffer);
        try out_stream.writeAll("\n");
    }
}
