const std = @import("std");
const mainForAlgorithm = @import("shared/checksum.zig").mainForAlgorithm;

const hash = std.crypto.hash;

pub fn main() !void {
    try mainForAlgorithm("SHA384", 384, std.crypto.hash.sha2.Sha384);
}
