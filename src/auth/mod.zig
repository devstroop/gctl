const std = @import("std");

pub const env = @import("env.zig");
pub const keychain = @import("keychain.zig");
pub const oauth = @import("oauth.zig");

/// Get a token for the given provider and account name.
/// Resolution order: env vars → keychain → config file.
/// Returns null if no token is found.
pub fn getToken(_: std.mem.Allocator, provider: []const u8, _: ?[]const u8) !?[]const u8 {
    // v0.1: env vars only
    return env.getToken(provider);
}
