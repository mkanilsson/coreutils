const std = @import("std");
const mainForAlgorithm = @import("shared/checksum.zig").mainForAlgorithm;

const hash = std.crypto.hash;

pub fn main() !void {
    try mainForAlgorithm("MD5", 128, std.crypto.hash.Md5);
}
