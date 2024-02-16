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
    \\-c, --check          Check and verify signatures.
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

    const check = res.args.check != 0;
    const tag = res.args.tag != 0;

    if (res.positionals.len == 0) {
        if (check) {
            try checkFile(allocator, stdin, "-", algorithm);
        } else {
            try printFile(stdin, "-", algorithm, name, tag);
        }
    } else {
        for (res.positionals) |file_path| {
            if (std.mem.eql(u8, file_path, "-")) {
                if (check) {
                    try checkFile(allocator, stdin, "-", algorithm);
                } else {
                    try printFile(stdin, "-", algorithm, name, tag);
                }
            } else {
                var file = try std.fs.cwd().openFile(file_path, .{});
                defer file.close();

                if (check) {
                    try checkFile(allocator, file.reader(), file_path, algorithm);
                } else {
                    try printFile(file.reader(), file_path, algorithm, name, tag);
                }
            }
        }
    }
}

fn computeFile(reader: anytype, algorithm: anytype) ![algorithm.digest_length]u8 {
    var hasher = algorithm.init(.{});

    var buffer: [2048]u8 = undefined;
    while (true) {
        var bytes_read = try reader.read(&buffer);
        if (bytes_read == 0) break;

        hasher.update(buffer[0..bytes_read]);
    }

    return hasher.finalResult();
}

fn printFile(reader: anytype, file_path: []const u8, algorithm: anytype, algorithm_name: []const u8, tag: bool) !void {
    const stdout = io.getStdOut().writer();

    const hash = try computeFile(reader, algorithm);

    if (tag) {
        try stdout.print("{s} ({s}) = {x}\n", .{ algorithm_name, file_path, std.fmt.fmtSliceHexLower(&hash) });
    } else {
        try stdout.print("{x}  {s}\n", .{ std.fmt.fmtSliceHexLower(&hash), file_path });
    }
}

fn checkFile(allocator: std.mem.Allocator, reader: anytype, file_path: []const u8, algorithm: anytype) !void {
    var line_number: usize = 1;
    const stdout = io.getStdOut().writer();

    while (true) {
        var line = std.ArrayList(u8).init(allocator);
        defer line.deinit();

        reader.streamUntilDelimiter(line.writer(), '\n', null) catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };

        const line_slice = try line.toOwnedSlice();
        defer allocator.free(line_slice);

        var parts = std.mem.split(u8, line_slice, "  ");
        const signature_hex = parts.next() orelse {
            try io.getStdErr().writer().print("{s} {} line is improperly formatted. Missing signature\n", .{ file_path, line_number });
            return;
        };

        var signature: [algorithm.digest_length]u8 = undefined;
        _ = std.fmt.hexToBytes(&signature, signature_hex) catch {
            try io.getStdErr().writer().print("{s} {} line is improperly formatted. Invalid signature\n", .{ file_path, line_number });
            return;
        };

        const file_path_to_check = parts.next() orelse {
            try io.getStdErr().writer().print("{s}  {} line is improperly formatted. Missing file path\n", .{ file_path, line_number });
            return;
        };

        var file = try std.fs.cwd().openFile(file_path_to_check, .{});
        defer file.close();

        const file_signature = try computeFile(file.reader(), algorithm);

        if (std.mem.eql(u8, &signature, &file_signature)) {
            try stdout.print("{s}: OK\n", .{file_path_to_check});
        } else {
            try stdout.print("{s}: FAILED\n", .{file_path_to_check});
        }
    }
}
