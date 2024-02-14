const std = @import("std");
const mainForAlgorithm = @import("shared/checksum.zig").mainForAlgorithm;

const hash = std.crypto.hash;

pub fn main() !void {
    try mainForAlgorithm("SHA512", 512, std.crypto.hash.sha2.Sha512);
}
