const clap = @import("clap");
const std = @import("std");

const CLI = @import("cli.zig").CLI;
const DefaultAllocator = @import("mem.zig").DefaultAllocator;

const io = std.io;

// Globals
// FIXME: Remove -t, only keep --tag (similar to: https://github.com/Hejsil/zig-clap/issues/115)
const params = clap.parseParamsComptime(
    \\-h, --help           Display this help and exit.
    \\-t, --tag            Create a BSD-style checksum.
    \\<FILE>...            Path to file.
    \\
);

const parsers = .{
    .FILE = clap.parsers.string,
};

pub fn mainForAlgorithm(comptime name: []const u8, comptime bit: usize, algorithm: anytype) !void {
    var default_allocator = DefaultAllocator;
    defer _ = default_allocator.deinit();
    var allocator = default_allocator.allocator();

    const description = std.fmt.comptimePrint("Print or check {s} ({}-bit) checksums", .{ name, bit });

    const cli = CLI(&params, parsers, description);

    var res = try cli.getCommandLineArguments(allocator);
    defer res.deinit();

    var stdin = io.getStdIn().reader();

    const tag = res.args.tag != 0;

    if (res.positionals.len == 0) {
        try computeFile(stdin, "-", algorithm, name, tag);
    } else {
        for (res.positionals) |file_path| {
            if (std.mem.eql(u8, file_path, "-")) {
                try computeFile(stdin, "-", algorithm, name, tag);
            } else {
                var file = try std.fs.cwd().openFile(file_path, .{});
                defer file.close();

                try computeFile(file.reader(), file_path, algorithm, name, tag);
            }
        }
    }
}

fn computeFile(reader: anytype, file_name: []const u8, algorithm: anytype, algorithm_name: []const u8, tag: bool) !void {
    var hasher = algorithm.init(.{});

    var buffer: [2048]u8 = undefined;
    while (true) {
        var bytes_read = try reader.read(&buffer);
        if (bytes_read == 0) break;

        hasher.update(buffer[0..bytes_read]);
    }

    var hash = hasher.finalResult();
    var stdout = io.getStdOut().writer();

    if (tag) {
        try stdout.print("{s} ({s}) = {x}\n", .{ algorithm_name, file_name, std.fmt.fmtSliceHexLower(&hash) });
    } else {
        try stdout.print("{x}  {s}\n", .{ std.fmt.fmtSliceHexLower(&hash), file_name });
    }
}
