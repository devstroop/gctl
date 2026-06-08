const std = @import("std");
const types = @import("types.zig");
const github = @import("github.zig");
const gitlab = @import("gitlab.zig");
const gitea = @import("gitea.zig");
const context = @import("context");
const cli = @import("cli");

// ── Provider registry ──────────────────────────────────────────────────────

const providers = [_]types.Provider{
    .{
        .name = "github",
        .base_url = "https://api.github.com",
        .repos = github.repo_vtable,
        .issues = github.issue_vtable,
        .prs = github.pr_vtable,
        .releases = null, // v0.4
        .pipelines = null, // v0.5
    },
    .{
        .name = "gitlab",
        .base_url = "https://gitlab.com/api/v4",
        .repos = gitlab.repo_vtable,
        .issues = gitlab.issue_vtable,
        .prs = gitlab.pr_vtable,
    },
    .{
        .name = "gitea",
        .base_url = "https://gitea.com/api/v1",
        .repos = null, // v0.4
        .issues = null, // v0.4
        .prs = null, // v0.4
        .releases = null, // v0.4
        .pipelines = null, // always null for Gitea
    },
    .{
        .name = "custom",
        .base_url = "", // set dynamically via --provider-url
        .repos = null,
        .issues = null,
        .prs = null,
        .releases = null,
        .pipelines = null,
    },
};

/// Find a provider by name.
pub fn getProvider(name: []const u8) ?*const types.Provider {
    for (&providers) |p| {
        if (std.mem.eql(u8, p.name, name)) return &p;
    }
    return null;
}

/// Execute a command against the resolved context.
pub fn execute(
    allocator: std.mem.Allocator,
    stdout: anytype,
    stderr: anytype,
    ctx: context.ResolvedContext,
    token: ?[]const u8,
    command: cli.Command,
    number: ?u64,
    provider_url: ?[]const u8,
    name: ?[]const u8,
    description: ?[]const u8,
    private: bool,
) !void {
    const provider = getProvider(ctx.provider);
    if (provider == null) {
        try stderr.interface.print("error: unknown provider '{s}'\n", .{ctx.provider});
        stderr.end() catch {};
        std.process.exit(1);
    }

    const p = provider.?;

    if (token == null) {
        try stderr.interface.print("error: no token for {s}\n", .{ctx.provider});
        try stderr.interface.print("Set {s}_TOKEN or run 'gctl auth login {s}'.\n", .{ upperEnvVar(ctx.provider), ctx.provider });
        stderr.end() catch {};
        std.process.exit(1);
    }

    const t = token.?;

    switch (command) {
        .context => try printContext(stdout, ctx, p, provider_url),
        .status => try printStatus(stdout, ctx, p, provider_url),
        .repo_view => try execRepoView(allocator, stdout, stderr, p, t, ctx),
        .repo_create => try execRepoCreate(allocator, stdout, stderr, p, t, ctx, name, description, private),
        .repo_delete => try execRepoDelete(allocator, stdout, stderr, p, t, ctx, name),
        .repo_archive => try execRepoArchive(allocator, stdout, stderr, p, t, ctx, name),
        .issue_list => try execIssueList(allocator, stdout, stderr, p, t, ctx),
        .issue_view => try execIssueView(allocator, stdout, stderr, p, t, ctx, number),
        .pr_list => try execPRList(allocator, stdout, stderr, p, t, ctx),
        .pr_view => try execPRView(allocator, stdout, stderr, p, t, ctx, number),
        .api => try stderr.interface.print("TODO: api command\n", .{}),
    }
}

fn printContext(writer: anytype, ctx: context.ResolvedContext, provider: *const types.Provider, provider_url: ?[]const u8) !void {
    _ = provider;
    try writer.interface.print("Provider:  {s}\n", .{ctx.provider});
    if (provider_url) |url| {
        try writer.interface.print("API URL:   {s}\n", .{url});
    }
    try writer.interface.print("Account:   not configured (env var token)\n", .{});
    try writer.interface.print("Owner:     {s}\n", .{ctx.owner});
    try writer.interface.print("Repo:      {s}\n", .{ctx.repo});
    try writer.interface.print("Remote:    {s} ({s})\n", .{ ctx.remote_name, ctx.remote_url });
    try writer.interface.print("Token:     {s}\n", .{ctx.token_source});
}

fn printStatus(writer: anytype, ctx: context.ResolvedContext, provider: *const types.Provider, provider_url: ?[]const u8) !void {
    _ = provider;
    _ = provider_url;
    try writer.interface.print("{s} → {s}/{s}\n", .{ ctx.provider, ctx.owner, ctx.repo });
}

fn execRepoCreate(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, name: ?[]const u8, description: ?[]const u8, private: bool) !void {
    if (provider.repos) |repos| {
        const repo_name = name orelse {
            try stderr.interface.print("error: repo create requires a name\n", .{});
            stderr.end() catch {};
            std.process.exit(1);
        };
        const params = types.RepoCreateParams{
            .name = repo_name,
            .description = description,
            .private = private,
        };
        const info = try repos.create(allocator, token, ctx.owner, params);
        try cli.output.printKeyValue(stdout, &.{
            .{ "Name", info.name },
            .{ "Full name", info.full_name },
            .{ "URL", info.url },
            .{ "Visibility", info.visibility },
        }, false);
        return;
    }
    try stderr.interface.print("error: {s} does not support repository creation.\n", .{provider.name});
    stderr.end() catch {};
    std.process.exit(1);
}

fn execRepoDelete(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, name: ?[]const u8) !void {
    if (provider.repos) |repos| {
        const repo_name = name orelse {
            try stderr.interface.print("error: repo delete requires a name\n", .{});
            stderr.end() catch {};
            std.process.exit(1);
        };
        try repos.delete(allocator, token, ctx.owner, repo_name);
        try stdout.interface.print("Deleted {s}/{s}\n", .{ ctx.owner, repo_name });
        return;
    }
    try stderr.interface.print("error: {s} does not support repository deletion.\n", .{provider.name});
    stderr.end() catch {};
    std.process.exit(1);
}

fn execRepoArchive(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, name: ?[]const u8) !void {
    if (provider.repos) |repos| {
        const repo_name = name orelse {
            try stderr.interface.print("error: repo archive requires a name\n", .{});
            stderr.end() catch {};
            std.process.exit(1);
        };
        const info = try repos.archive(allocator, token, ctx.owner, repo_name, true);
        try cli.output.printKeyValue(stdout, &.{
            .{ "Name", info.name },
            .{ "Archived", if (info.visibility.len > 0) "yes" else "yes" },
            .{ "URL", info.url },
        }, false);
        return;
    }
    try stderr.interface.print("error: {s} does not support repository archiving.\n", .{provider.name});
    stderr.end() catch {};
    std.process.exit(1);
}

fn execRepoView(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext) !void {
    if (provider.repos) |repos| {
        const info = try repos.view(allocator, token, ctx.owner, ctx.repo);
        try cli.output.printKeyValue(stdout, &.{
            .{ "Name", info.name },
            .{ "Full name", info.full_name },
            .{ "Description", info.description },
            .{ "URL", info.url },
            .{ "Default branch", info.default_branch },
            .{ "Visibility", info.visibility },
        }, false);
        return;
    }
    try stderr.interface.print("error: {s} does not support repository operations.\n", .{provider.name});
    stderr.end() catch {};
    std.process.exit(1);
}

fn execIssueList(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext) !void {
    if (provider.issues) |issues| {
        const list = try issues.list(allocator, token, ctx.owner, ctx.repo);
        const headers = [_][]const u8{ "#", "Title", "Author", "Labels", "State" };
        var rows = try std.ArrayList([]const []const u8).initCapacity(allocator, list.len);
        defer rows.deinit(allocator);
        for (list) |item| {
            const row = [_][]const u8{
                try std.fmt.allocPrint(allocator, "{d}", .{item.number}),
                item.title,
                item.author,
                try std.mem.join(allocator, ", ", item.labels),
                item.state,
            };
            try rows.append(allocator, &row);
        }
        try cli.output.printTable(stdout, &headers, rows.items, false);
        return;
    }
    try stderr.interface.print("error: {s} does not support issues.\n", .{provider.name});
    stderr.end() catch {};
    std.process.exit(1);
}

fn execIssueView(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, number: ?u64) !void {
    if (provider.issues) |issues| {
        const num = number orelse {
            try stderr.interface.print("error: issue view requires an issue number\n", .{});
            stderr.end() catch {};
            std.process.exit(1);
        };
        const info = try issues.view(allocator, token, ctx.owner, ctx.repo, num);
        try cli.output.printKeyValue(stdout, &.{
            .{ "Title", info.title },
            .{ "State", info.state },
            .{ "Author", info.author },
            .{ "URL", info.url },
            .{ "Created", info.created_at },
        }, false);
        try stdout.interface.print("\n{s}\n", .{info.body});
        return;
    }
    try stderr.interface.print("error: {s} does not support issues.\n", .{provider.name});
    stderr.end() catch {};
    std.process.exit(1);
}

fn execPRList(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext) !void {
    if (provider.prs) |prs| {
        const list = try prs.list(allocator, token, ctx.owner, ctx.repo);
        const headers = [_][]const u8{ "#", "Title", "Author", "Branch", "State" };
        var rows = try std.ArrayList([]const []const u8).initCapacity(allocator, list.len);
        defer rows.deinit(allocator);
        for (list) |item| {
            const draft = if (item.draft) " [draft]" else "";
            const title = try std.fmt.allocPrint(allocator, "{s}{s}", .{ item.title, draft });
            const row = [_][]const u8{
                try std.fmt.allocPrint(allocator, "{d}", .{item.number}),
                title,
                item.author,
                item.source_branch,
                item.state,
            };
            try rows.append(allocator, &row);
        }
        try cli.output.printTable(stdout, &headers, rows.items, false);
        return;
    }
    try stderr.interface.print("error: {s} does not support pull requests.\n", .{provider.name});
    stderr.end() catch {};
    std.process.exit(1);
}

fn execPRView(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, number: ?u64) !void {
    if (provider.prs) |prs| {
        const num = number orelse {
            try stderr.interface.print("error: PR view requires a PR number\n", .{});
            stderr.end() catch {};
            std.process.exit(1);
        };
        const info = try prs.view(allocator, token, ctx.owner, ctx.repo, num);
        const draft = if (info.draft) " [draft]" else "";
        try cli.output.printKeyValue(stdout, &.{
            .{ "Title", info.title },
            .{ "State", info.state },
            .{ "Author", info.author },
            .{ "Draft", if (info.draft) "yes" else "no" },
            .{ "Source", info.source_branch },
            .{ "Target", info.target_branch },
            .{ "URL", info.url },
            .{ "Created", info.created_at },
        }, false);
        _ = draft;
        return;
    }
    try stderr.interface.print("error: {s} does not support pull requests.\n", .{provider.name});
    stderr.end() catch {};
    std.process.exit(1);
}

fn upperEnvVar(provider: []const u8) []const u8 {
    if (std.mem.eql(u8, provider, "github")) return "GITHUB";
    if (std.mem.eql(u8, provider, "gitlab")) return "GITLAB";
    if (std.mem.eql(u8, provider, "gitea")) return "GITEA";
    return provider;
}

test {
    _ = providers;
    _ = getProvider;
    _ = execute;
}
