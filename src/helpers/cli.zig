const clap = @import("clap");
const std = @import("std");

const process = std.process;
const io = std.io;

pub fn CLI(comptime params: []const clap.Param(clap.Help), comptime parsers: anytype, comptime description: []const u8) type {
    return struct {
        pub fn getCommandLineArguments(allocator: std.mem.Allocator) !clap.Result(clap.Help, params, parsers) {
            var diagnostic = clap.Diagnostic{};

            var res = clap.parse(clap.Help, params, parsers, .{
                .diagnostic = &diagnostic,
                .allocator = allocator,
            }) catch |err| {
                diagnostic.report(io.getStdErr().writer(), err) catch {};
                return err;
            };

            return res;
        }

        pub fn printUsageAndHelp(allocator: std.mem.Allocator, stream: anytype, message: ?[]const u8) !void {
            const args = try process.argsAlloc(allocator);
            defer process.argsFree(allocator, args);
            var program = args[0];

            if (message) |msg| {
                try stream.print("{s}\n", .{msg});
            }

            try stream.print("Usage: {s} ", .{program});
            try clap.usage(stream, clap.Help, params);
            try stream.print("\n{s}\n", .{description});
            try clap.help(stream, clap.Help, params, .{});
        }
    };
}
