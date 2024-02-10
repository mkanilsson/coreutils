const std = @import("std");

const programs = [_][]const u8{ "head", "yes", "false", "true", "basename", "printenv", "cat" };

pub fn build(b: *std.Build) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const clap = b.dependency("clap", .{ .optimize = optimize, .target = target });
    const clap_module = clap.module("clap");

    for (programs) |program| {
        const src_path = try std.fmt.allocPrint(allocator, "src/{s}.zig", .{program});
        defer _ = allocator.free(src_path);
        const run_text = try std.fmt.allocPrint(allocator, "Run '{s}'", .{program});
        defer _ = allocator.free(run_text);

        const exe = b.addExecutable(.{
            .name = program,
            .root_source_file = .{ .path = src_path },
            .target = target,
            .optimize = optimize,
        });

        exe.addModule("clap", clap_module);

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);

        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step(program, run_text);
        run_step.dependOn(&run_cmd.step);
    }
}
