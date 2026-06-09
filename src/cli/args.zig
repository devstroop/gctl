const std = @import("std");

// ── Command tree ───────────────────────────────────────────────────────────
pub const Command = enum {
    doctor,
    network,
    status,
    @"export",
    import,
    copy,
    diff,
    repo_view,
    repo_create,
    repo_delete,
    repo_archive,
    label_set_all,
    issue_create,
    issue_close,
    issue_list,
    issue_view,
    pr_create,
    pr_merge,
    pr_list,
    pr_view,
    release_list,
    release_view,
    release_create,
    run_list,
    run_view,
    run_rerun,
    api,
    auth_login,
    auth_logout,
    auth_list,
    auth_status,
    completion,
};

pub const ParsedArgs = struct {
    command: Command,
    provider_override: ?[]const u8 = null,
    provider_url: ?[]const u8 = null,
    account: ?[]const u8 = null,
    // Command-specific args
    number: ?u64 = null,
    owner_repo: ?[]const u8 = null,
    method: ?[]const u8 = null,
    path: ?[]const u8 = null,
    name: ?[]const u8 = null,
    description: ?[]const u8 = null,
    private: bool = false,
    labels: ?[]const u8 = null,
    title: ?[]const u8 = null,
    base: ?[]const u8 = null,
    source: ?[]const u8 = null,
    target: ?[]const u8 = null,
    all: bool = false,
    quick: bool = false,
    json: bool = false,
};

/// Parse CLI arguments and return the parsed command and flags.
/// Returns error.HelpRequested if --help or -h is passed.
/// Returns error.InvalidCommand if the first arg doesn't match any command.
pub fn parseArgs(allocator: std.mem.Allocator, args: []const []const u8) !ParsedArgs {
    if (args.len == 0) return error.InvalidCommand;

    // Check for --help / -h
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            return error.HelpRequested;
        }
    }

    // Find first non-flag arg as the command candidate
    var cmd_start: usize = 0;
    while (cmd_start < args.len and (std.mem.startsWith(u8, args[cmd_start], "--") or std.mem.startsWith(u8, args[cmd_start], "-"))) : (cmd_start += 1) {
        // Skip past flag value args: --foo bar or -f bar (consume two)
        const a = args[cmd_start];
        if ((std.mem.eql(u8, a, "--provider") or std.mem.eql(u8, a, "-p") or
            std.mem.eql(u8, a, "--account") or std.mem.eql(u8, a, "-a") or
            std.mem.eql(u8, a, "--provider-url") or std.mem.eql(u8, a, "-u") or
            std.mem.eql(u8, a, "--description") or std.mem.eql(u8, a, "--base")) and
            cmd_start + 1 < args.len and !std.mem.startsWith(u8, args[cmd_start + 1], "-"))
        {
            cmd_start += 1; // skip the value too
        }
    }

    if (cmd_start >= args.len) return error.InvalidCommand;

    // Map command string to Command enum
    // Support both "repo_view" and "repo view" style
    const cmd = args[cmd_start];
    var command: ?Command = std.meta.stringToEnum(Command, cmd);
    var arg_offset: usize = cmd_start + 1;

    if (command == null and cmd_start + 1 < args.len) {
        // Check if next arg can combine: "repo" + "view" → "repo_view"
        // Skip past any flags between them
        const next = args[cmd_start + 1];
        if (!std.mem.startsWith(u8, next, "-")) {
            const combined = std.fmt.allocPrint(allocator, "{s}_{s}", .{ cmd, next }) catch return error.InvalidCommand;
            defer allocator.free(combined);
            command = std.meta.stringToEnum(Command, combined);
            if (command != null) {
                arg_offset = cmd_start + 2; // consumed two args for the command
            }
        }
    }

    if (command == null) return error.InvalidCommand;

    // Parse flags and positional args (simplified for v0.1)
    // Re-scan all args except the command word(s)
    var result = ParsedArgs{ .command = command.? };

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        // Skip command word(s)
        if (i >= cmd_start and i < arg_offset) continue;

        const arg = args[i];
        if (std.mem.eql(u8, arg, "--provider") or std.mem.eql(u8, arg, "-p")) {
            i += 1;
            if (i < args.len) {
                result.provider_override = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--account") or std.mem.eql(u8, arg, "-a")) {
            i += 1;
            if (i < args.len) {
                result.account = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--provider-url") or std.mem.eql(u8, arg, "-u")) {
            i += 1;
            if (i < args.len) {
                result.provider_url = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--description")) {
            i += 1;
            if (i < args.len) {
                result.description = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--base")) {
            i += 1;
            if (i < args.len) {
                result.base = args[i];
            }
        } else if (std.mem.eql(u8, arg, "--all")) {
            result.all = true;
        } else if (std.mem.eql(u8, arg, "--quick")) {
            result.quick = true;
        } else if (std.mem.eql(u8, arg, "--json") or std.mem.eql(u8, arg, "-j")) {
            result.json = true;
        } else if (std.mem.eql(u8, arg, "--private")) {
            result.private = true;
        } else if (std.mem.eql(u8, arg, "--no-private")) {
            result.private = false;
        } else if (std.mem.startsWith(u8, arg, "--provider=")) {
            result.provider_override = arg["--provider=".len..];
        } else if (std.mem.startsWith(u8, arg, "--account=")) {
            result.account = arg["--account=".len..];
        } else if (std.mem.startsWith(u8, arg, "--provider-url=")) {
            result.provider_url = arg["--provider-url=".len..];
        } else {
            // Positional args based on command
            switch (command.?) {
                .issue_view, .issue_close => {
                    result.number = std.fmt.parseUnsigned(u64, arg, 10) catch null;
                },
                .pr_view, .pr_merge => {
                    result.number = std.fmt.parseUnsigned(u64, arg, 10) catch null;
                },
                .run_view, .run_rerun => {
                    result.number = std.fmt.parseUnsigned(u64, arg, 10) catch null;
                },
                .pr_create => {
                    result.title = arg;
                },
                .issue_create => {
                    result.title = arg;
                },
                .repo_view => {
                    result.owner_repo = arg;
                },
                .repo_create => {
                    if (result.name == null) {
                        result.name = arg;
                    }
                },
                .repo_delete, .repo_archive => {
                    if (result.name == null) {
                        result.name = arg;
                    }
                },
                .release_view, .release_create => {
                    if (result.name == null) {
                        result.name = arg;
                    }
                },
                .label_set_all => {
                    result.labels = arg;
                },
                .api => {
                    if (result.method == null) {
                        result.method = arg;
                    } else if (result.path == null) {
                        result.path = arg;
                    }
                },
                .@"export", .import => {
                    if (result.path == null) {
                        result.path = arg;
                    }
                },
                .completion => {
                    if (result.path == null) {
                        result.path = arg;
                    }
                },
                .copy, .diff => {
                    if (result.source == null) {
                        result.source = arg;
                    } else if (result.target == null) {
                        result.target = arg;
                    }
                },
                .auth_login, .auth_logout => {
                    if (result.name == null) {
                        result.name = arg;
                    }
                },
                else => {},
            }
        }
    }

    return result;
}

pub fn printHelp(writer: anytype) !void {
    try writer.interface.writeAll(
        \\gitctl — Cross-forge Git operations, one CLI
        \\
        \\Usage: gitctl <command> [options]
        \\
        \\Commands:
        \\  doctor [--quick]       System diagnostics (omit token checks with --quick)
        \\  network [--all]        Show all remotes with provider, owner, repo
        \\  status                 Repo pulse: open issues, PRs, latest activity
        \\  repo view [owner/repo] View repository details
        \\  repo create <name>     Create a repository
        \\  repo delete <name>     Delete a repository
        \\  repo archive <name>    Archive/unarchive a repository
        \\  label set_all <labels> Replace all repo labels (comma-separated)
        \\  issue create <title>   Create an issue
        \\  issue close <number>   Close an issue
        \\  issue list             List open issues
        \\  issue view <number>    View an issue
        \\  pr create <title>      Create a pull/merge request
        \\  pr merge <number>      Merge a pull/merge request
        \\  pr list                List open pull/merge requests
        \\  pr view <number>       View a pull/merge request
        \\  release list           List releases
        \\  release view <tag>     View a release
        \\  release create <tag>   Create a release
        \\  run list               List CI/CD runs
        \\  run view <id>          View a CI/CD run
        \\  run rerun <id>         Rerun a CI/CD run
        \\  api <method> <path>    Direct API call
        \\  export <resource-path>  Write resource as JSON to stdout
        \\  import <resource-path>  Create resource from JSON on stdin
        \\  copy <source> <target>  Copy resource across remotes (export | import)
        \\  diff <source> <target>  Compare resource across remotes
        \\  auth login <provider>   Store a token for provider (prompts for token)
        \\  auth logout <provider>  Remove stored token for provider
        \\  auth list               Show all configured accounts
        \\  auth status             Show current authentication context
        \\  completion <shell>      Generate shell completions (bash|zsh|fish)
        \\
        \\Flags:
        \\  --provider, -p <name>     Override provider (github|gitlab)
        \\  --provider-url, -u <url>  Base URL for custom provider
        \\  --account, -a <name>      Override account
        \\  --description <text>      Repo description (repo create)
        \\  --private                 Make repo private (repo create)
        \\  --base <branch>           Target branch (pr create, default: main)
        \\  --json, -j                Output as JSON
        \\  --help, -h                Show this help
        \\
        \\Environment:
        \\  GITHUB_TOKEN       GitHub personal access token
        \\  GITLAB_TOKEN       GitLab personal access token
        \\  TOKEN              Generic token for custom providers
        \\
        \\Examples:
        \\  gitctl doctor
        \\  gitctl doctor --quick
        \\  gitctl repo create my-project --private --description "My thing"
        \\
    );
}

test {
    _ = Command;
    _ = ParsedArgs;
    _ = parseArgs;
}
