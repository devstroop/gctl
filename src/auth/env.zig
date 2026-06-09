const std = @import("std");

/// Return the env var name for a given provider.
pub fn varName(provider: []const u8) []const u8 {
    if (std.mem.eql(u8, provider, "github")) return "GITHUB_TOKEN";
    if (std.mem.eql(u8, provider, "gitlab")) return "GITLAB_TOKEN";
    if (std.mem.eql(u8, provider, "gitea")) return "GITEA_TOKEN";
    return "TOKEN"; // generic fallback for custom / unknown providers
}

/// Cross-platform env var lookup. Returns null if not found.
/// Caller owns the returned memory if non-null.
pub fn getEnvVarOwned(allocator: std.mem.Allocator, name: []const u8) !?[]const u8 {
    return std.process.getEnvVarOwned(allocator, name) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => return null,
        else => |e| return e,
    };
}

/// Get a token from environment variables.
/// Checks: GITHUB_TOKEN, GITLAB_TOKEN, GITEA_TOKEN, TOKEN (generic fallback).
/// Caller owns the returned memory if non-null.
pub fn getToken(allocator: std.mem.Allocator, provider: []const u8) !?[]const u8 {
    return try getEnvVarOwned(allocator, varName(provider));
}

test {
    _ = getToken;
}
