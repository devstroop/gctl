const std = @import("std");
const auth = @import("auth");

test "env: varName maps providers correctly" {
    try std.testing.expectEqualStrings("GITHUB_TOKEN", auth.env.varName("github"));
    try std.testing.expectEqualStrings("GITLAB_TOKEN", auth.env.varName("gitlab"));
    try std.testing.expectEqualStrings("GITEA_TOKEN", auth.env.varName("gitea"));
    try std.testing.expectEqualStrings("TOKEN", auth.env.varName("custom"));
    try std.testing.expectEqualStrings("TOKEN", auth.env.varName("unknown"));
}

test "env: getToken returns null for unset vars" {
    const result = try auth.env.getToken(std.testing.allocator, "github");
    try std.testing.expect(result == null);
}

test "env: getToken returns null for gitlab" {
    const result = try auth.env.getToken(std.testing.allocator, "gitlab");
    try std.testing.expect(result == null);
}

test "env: getToken returns null for gitea" {
    const result = try auth.env.getToken(std.testing.allocator, "gitea");
    try std.testing.expect(result == null);
}

test "getToken: returns null when no token is available" {
    const result = try auth.getToken(std.testing.allocator, "github", null);
    try std.testing.expect(result == null);
}

test "getToken: returns null when env unset and account not provided" {
    const result = try auth.getToken(std.testing.allocator, "gitlab", null);
    try std.testing.expect(result == null);
}

test {
    _ = auth;
    _ = auth.env;
}
