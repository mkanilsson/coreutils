const std = @import("std");
const mainForAlgorithm = @import("shared/checksum.zig").mainForAlgorithm;

const hash = std.crypto.hash;

pub fn main() !void {
    try mainForAlgorithm("SHA1", 160, std.crypto.hash.Sha1);
}
