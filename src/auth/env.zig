const std = @import("std");

/// Return the env var name for a given provider.
pub fn varName(provider: []const u8) []const u8 {
    if (std.mem.eql(u8, provider, "github")) return "GITHUB_TOKEN";
    if (std.mem.eql(u8, provider, "gitlab")) return "GITLAB_TOKEN";
    if (std.mem.eql(u8, provider, "gitea")) return "GITEA_TOKEN";
    return "TOKEN"; // generic fallback for custom / unknown providers
}

/// Get a token from environment variables.
/// Checks: GITHUB_TOKEN, GITLAB_TOKEN, GITEA_TOKEN, TOKEN (generic fallback).
pub fn getToken(provider: []const u8) !?[]const u8 {
    return std.posix.getenv(varName(provider));
}

test {
    _ = getToken;
}
