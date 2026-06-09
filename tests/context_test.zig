const std = @import("std");
const context = @import("context");

test "parseRemote: github HTTPS" {
    const allocator = std.testing.allocator;
    const url = "https://github.com/owner/repo.git";

    const result = context.parseRemote(url, allocator);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("github", result.?.provider);
    try std.testing.expectEqualStrings("owner", result.?.owner);
    try std.testing.expectEqualStrings("repo", result.?.repo);

    allocator.free(result.?.provider);
    allocator.free(result.?.owner);
    allocator.free(result.?.repo);
}

test "parseRemote: github HTTPS without .git suffix" {
    const allocator = std.testing.allocator;
    const url = "https://github.com/myorg/myrepo";

    const result = context.parseRemote(url, allocator);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("github", result.?.provider);
    try std.testing.expectEqualStrings("myorg", result.?.owner);
    try std.testing.expectEqualStrings("myrepo", result.?.repo);

    allocator.free(result.?.provider);
    allocator.free(result.?.owner);
    allocator.free(result.?.repo);
}

test "parseRemote: github SSH" {
    const allocator = std.testing.allocator;
    const url = "git@github.com:owner/repo.git";

    const result = context.parseRemote(url, allocator);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("github", result.?.provider);
    try std.testing.expectEqualStrings("owner", result.?.owner);
    try std.testing.expectEqualStrings("repo", result.?.repo);

    allocator.free(result.?.provider);
    allocator.free(result.?.owner);
    allocator.free(result.?.repo);
}

test "parseRemote: gitlab self-hosted SSH" {
    const allocator = std.testing.allocator;
    const url = "git@gitlab.company.com:team/project.git";

    const result = context.parseRemote(url, allocator);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("gitlab", result.?.provider);
    try std.testing.expectEqualStrings("team", result.?.owner);
    try std.testing.expectEqualStrings("project", result.?.repo);

    allocator.free(result.?.provider);
    allocator.free(result.?.owner);
    allocator.free(result.?.repo);
}

test "parseRemote: gitlab self-hosted HTTPS" {
    const allocator = std.testing.allocator;
    const url = "https://gitlab.company.com/team/project.git";

    const result = context.parseRemote(url, allocator);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("gitlab", result.?.provider);
    try std.testing.expectEqualStrings("team", result.?.owner);
    try std.testing.expectEqualStrings("project", result.?.repo);

    allocator.free(result.?.provider);
    allocator.free(result.?.owner);
    allocator.free(result.?.repo);
}

test "parseRemote: gitea.com HTTPS" {
    const allocator = std.testing.allocator;
    const url = "https://gitea.com/user/repo.git";

    const result = context.parseRemote(url, allocator);
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("gitea", result.?.provider);
    try std.testing.expectEqualStrings("user", result.?.owner);
    try std.testing.expectEqualStrings("repo", result.?.repo);

    allocator.free(result.?.provider);
    allocator.free(result.?.owner);
    allocator.free(result.?.repo);
}

test "parseRemote: unknown URL returns null" {
    const allocator = std.testing.allocator;
    const url = "https://bitbucket.org/owner/repo.git";

    const result = context.parseRemote(url, allocator);
    try std.testing.expect(result == null);
}

test "parseRemote: unknown SSH URL returns null" {
    const allocator = std.testing.allocator;
    const url = "git@bitbucket.org:owner/repo.git";

    const result = context.parseRemote(url, allocator);
    try std.testing.expect(result == null);
}

test "resolve: auto-detection from git remote" {
    const allocator = std.testing.allocator;

    const result = context.resolve(allocator, null, null) catch return;
    defer context.contextsDeinit(result, allocator);
    try std.testing.expect(result.len > 0);
    try std.testing.expect(result[0].remote_name.len > 0);
    try std.testing.expect(result[0].remote_url.len > 0);
}
