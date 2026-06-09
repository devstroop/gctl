const std = @import("std");
const cli = @import("cli");

test "parseArgs: no args" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{};
    try std.testing.expectError(error.InvalidCommand, cli.parseArgs(allocator, &args));
}

test "parseArgs: doctor command" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{"doctor"};
    const result = try cli.parseArgs(allocator, &args);
    try std.testing.expectEqual(cli.Command.doctor, result.command);
    try std.testing.expect(result.provider_override == null);
    try std.testing.expectEqual(false, result.quick);
}

test "parseArgs: status command" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{"status"};
    const result = try cli.parseArgs(allocator, &args);
    try std.testing.expectEqual(cli.Command.status, result.command);
}

test "parseArgs: issue list" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "issue", "list" };
    const result = try cli.parseArgs(allocator, &args);
    try std.testing.expectEqual(cli.Command.issue_list, result.command);
    try std.testing.expect(result.number == null);
}

test "parseArgs: issue view with number" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "issue", "view", "42" };
    const result = try cli.parseArgs(allocator, &args);
    try std.testing.expectEqual(cli.Command.issue_view, result.command);
    try std.testing.expect(result.number != null);
    try std.testing.expectEqual(@as(u64, 42), result.number.?);
}

test "parseArgs: pr list" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "pr", "list" };
    const result = try cli.parseArgs(allocator, &args);
    try std.testing.expectEqual(cli.Command.pr_list, result.command);
}

test "parseArgs: pr view with number" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "pr", "view", "7" };
    const result = try cli.parseArgs(allocator, &args);
    try std.testing.expectEqual(cli.Command.pr_view, result.command);
    try std.testing.expectEqual(@as(u64, 7), result.number.?);
}

test "parseArgs: repo view" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "repo", "view" };
    const result = try cli.parseArgs(allocator, &args);
    try std.testing.expectEqual(cli.Command.repo_view, result.command);
}

test "parseArgs: repo view with owner/repo" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "repo", "view", "myorg/myrepo" };
    const result = try cli.parseArgs(allocator, &args);
    try std.testing.expectEqual(cli.Command.repo_view, result.command);
    try std.testing.expectEqualStrings("myorg/myrepo", result.owner_repo.?);
}

test "parseArgs: api GET /user" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "api", "GET", "/user" };
    const result = try cli.parseArgs(allocator, &args);
    try std.testing.expectEqual(cli.Command.api, result.command);
    try std.testing.expectEqualStrings("GET", result.method.?);
    try std.testing.expectEqualStrings("/user", result.path.?);
}

test "parseArgs: --provider flag before doctor" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "--provider", "gitlab", "doctor" };
    const result = try cli.parseArgs(allocator, &args);
    try std.testing.expectEqual(cli.Command.doctor, result.command);
    try std.testing.expectEqualStrings("gitlab", result.provider_override.?);
}

test "parseArgs: --provider flag after doctor" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "doctor", "--provider", "gitlab" };
    const result = try cli.parseArgs(allocator, &args);
    try std.testing.expectEqual(cli.Command.doctor, result.command);
    try std.testing.expectEqualStrings("gitlab", result.provider_override.?);
}

test "parseArgs: --provider= equals style with doctor" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "--provider=gitlab", "doctor" };
    const result = try cli.parseArgs(allocator, &args);
    try std.testing.expectEqual(cli.Command.doctor, result.command);
    try std.testing.expectEqualStrings("gitlab", result.provider_override.?);
}

test "parseArgs: --provider-url flag with doctor" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "--provider-url", "https://git.example.com/api/v1", "doctor" };
    const result = try cli.parseArgs(allocator, &args);
    try std.testing.expectEqual(cli.Command.doctor, result.command);
    try std.testing.expectEqualStrings("https://git.example.com/api/v1", result.provider_url.?);
}

test "parseArgs: -p short flag with doctor" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "-p", "gitea", "doctor" };
    const result = try cli.parseArgs(allocator, &args);
    try std.testing.expectEqual(cli.Command.doctor, result.command);
    try std.testing.expectEqualStrings("gitea", result.provider_override.?);
}

test "parseArgs: --account flag with doctor" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "--account", "personal", "doctor" };
    const result = try cli.parseArgs(allocator, &args);
    try std.testing.expectEqual(cli.Command.doctor, result.command);
    try std.testing.expectEqualStrings("personal", result.account.?);
}

test "parseArgs: --help flag before command" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{"--help"};
    try std.testing.expectError(error.HelpRequested, cli.parseArgs(allocator, &args));
}

test "parseArgs: --help flag with command" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "issue", "list", "--help" };
    try std.testing.expectError(error.HelpRequested, cli.parseArgs(allocator, &args));
}

test "parseArgs: -h short flag" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{"-h"};
    try std.testing.expectError(error.HelpRequested, cli.parseArgs(allocator, &args));
}

test "parseArgs: unknown command" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{"blarg"};
    try std.testing.expectError(error.InvalidCommand, cli.parseArgs(allocator, &args));
}

test "parseArgs: flags only without command" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "--provider", "github" };
    try std.testing.expectError(error.InvalidCommand, cli.parseArgs(allocator, &args));
}

test "parseArgs: combined flags and positional args" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "--account", "work", "pr", "view", "99" };
    const result = try cli.parseArgs(allocator, &args);
    try std.testing.expectEqual(cli.Command.pr_view, result.command);
    try std.testing.expectEqualStrings("work", result.account.?);
    try std.testing.expectEqual(@as(u64, 99), result.number.?);
}
