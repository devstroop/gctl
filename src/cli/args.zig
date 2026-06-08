const std = @import("std");

// ── Command tree ───────────────────────────────────────────────────────────
pub const Command = enum {
    context,
    status,
    repo_view,
    issue_list,
    issue_view,
    pr_list,
    pr_view,
    api,
    // v0.3+
    // issue_create,
    // issue_close,
    // pr_create,
    // pr_merge,
    // v0.4+
    // release_list,
    // release_view,
    // release_create,
    // v0.5+
    // run_list,
    // run_view,
    // run_rerun,
    // v1.0+
    // auth_login,
    // auth_logout,
    // auth_list,
    // auth_status,
    // doctor,
    // completion,
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
            std.mem.eql(u8, a, "--provider-url") or std.mem.eql(u8, a, "-u")) and
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
        } else if (std.mem.startsWith(u8, arg, "--provider=")) {
            result.provider_override = arg["--provider=".len..];
        } else if (std.mem.startsWith(u8, arg, "--account=")) {
            result.account = arg["--account=".len..];
        } else if (std.mem.startsWith(u8, arg, "--provider-url=")) {
            result.provider_url = arg["--provider-url=".len..];
        } else {
            // Positional args based on command
            switch (command.?) {
                .issue_view, .pr_view => {
                    result.number = std.fmt.parseUnsigned(u64, arg, 10) catch null;
                },
                .repo_view => {
                    result.owner_repo = arg;
                },
                .api => {
                    if (result.method == null) {
                        result.method = arg;
                    } else if (result.path == null) {
                        result.path = arg;
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
        \\gctl — One CLI for every Git forge
        \\
        \\Usage: gctl <command> [options]
        \\
        \\Commands:
        \\  context              Show detected provider and repo context
        \\  status               High-level repo summary
        \\  repo view [owner/repo]  View repository details
        \\  issue list           List open issues
        \\  issue view <number>  View an issue
        \\  pr list              List open pull requests
        \\  pr view <number>     View a pull request
        \\  api <method> <path>  Direct API call
        \\
        \\Global flags:
        \\  --provider, -p <name>   Override provider (github|gitlab|gitea|custom)
        \\  --provider-url, -u <url> Base URL for custom provider
        \\  --account, -a <name>    Override account
        \\  --help, -h              Show this help
        \\
        \\Environment:
        \\  GITHUB_TOKEN       GitHub personal access token
        \\  GITLAB_TOKEN       GitLab personal access token
        \\  GITEA_TOKEN        Gitea/Forgejo token
        \\  TOKEN              Generic token (for custom providers)
        \\
        \\Examples:
        \\  gctl context
        \\  gctl issue list
        \\  gctl --provider custom --provider-url https://git.example.com/api/v1 context
        \\
    );
}

test {
    _ = Command;
    _ = ParsedArgs;
    _ = parseArgs;
}
