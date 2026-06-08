const std = @import("std");

/// Get a token from environment variables.
/// Checks: GITHUB_TOKEN, GITLAB_TOKEN, GITEA_TOKEN, TOKEN (generic fallback).
pub fn getToken(provider: []const u8) !?[]const u8 {
    const var_name = if (std.mem.eql(u8, provider, "github"))
        "GITHUB_TOKEN"
    else if (std.mem.eql(u8, provider, "gitlab"))
        "GITLAB_TOKEN"
    else if (std.mem.eql(u8, provider, "gitea"))
        "GITEA_TOKEN"
    else
        "TOKEN"; // generic fallback for custom / unknown providers

    return std.posix.getenv(var_name);
}

test {
    _ = getToken;
}
