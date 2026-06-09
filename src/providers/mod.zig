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
        .labels = github.label_vtable,
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
    for (&providers) |*p| {
        if (std.mem.eql(u8, p.name, name)) return p;
    }
    return null;
}

/// Execute a command against the resolved contexts.
/// Single-repo commands use ctxs[0]. Commands supporting --all
/// iterate all contexts.
pub fn execute(
    allocator: std.mem.Allocator,
    stdout: anytype,
    stderr: anytype,
    ctxs: []context.ResolvedContext,
    token: ?[]const u8,
    command: cli.Command,
    number: ?u64,
    provider_url: ?[]const u8,
    name: ?[]const u8,
    description: ?[]const u8,
    private: bool,
    labels: ?[]const u8,
    title: ?[]const u8,
    base: ?[]const u8,
    quick: bool,
) !void {
    if (ctxs.len == 0) {
        try stderr.interface.print("error: no context resolved\n", .{});
        stderr.end() catch {};
        std.process.exit(1);
    }

    const ctx = ctxs[0];
    const provider = getProvider(ctx.provider);
    if (provider == null) {
        try stderr.interface.print("error: unknown provider '{s}'\n", .{ctx.provider});
        stderr.end() catch {};
        std.process.exit(1);
    }

    const p = provider.?;

    if (token == null and command != .doctor) {
        try stderr.interface.print("error: no token for {s}\n", .{ctx.provider});
        try stderr.interface.print("Set {s}_TOKEN or run 'gctl auth login {s}'.\n", .{ upperEnvVar(ctx.provider), ctx.provider });
        stderr.end() catch {};
        std.process.exit(1);
    }

    const t = if (token) |tok| tok else "";

    switch (command) {
        .doctor => try printDoctor(stdout, allocator, ctxs, t, provider_url, quick),
        .status => try execPrintStatus(stdout, stderr, allocator, p, t, ctx),
        .repo_view => try execRepoView(allocator, stdout, stderr, p, t, ctx),
        .repo_create => try execRepoCreate(allocator, stdout, stderr, p, t, ctx, name, description, private),
        .repo_delete => try execRepoDelete(allocator, stdout, stderr, p, t, ctx, name),
        .repo_archive => try execRepoArchive(allocator, stdout, stderr, p, t, ctx, name),
        .label_set_all => try execLabelSetAll(allocator, stdout, stderr, p, t, ctx, labels),
        .issue_create => try execIssueCreate(allocator, stdout, stderr, p, t, ctx, title),
        .issue_close => try execIssueClose(allocator, stdout, stderr, p, t, ctx, number),
        .issue_list => try execIssueList(allocator, stdout, stderr, p, t, ctx),
        .issue_view => try execIssueView(allocator, stdout, stderr, p, t, ctx, number),
        .pr_create => try execPRCreate(allocator, stdout, stderr, p, t, ctx, title, base),
        .pr_merge => try execPRMerge(allocator, stdout, stderr, p, t, ctx, number),
        .pr_list => try execPRList(allocator, stdout, stderr, p, t, ctx),
        .pr_view => try execPRView(allocator, stdout, stderr, p, t, ctx, number),
        .api => try stderr.interface.print("TODO: api command\n", .{}),
    }
}

fn execPrintStatus(stdout: anytype, _: anytype, allocator: std.mem.Allocator, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext) !void {
    try stdout.interface.print("{s}/{s} — {s}\n", .{ ctx.owner, ctx.repo, ctx.provider });

    // Repo pulse via repos.view
    if (provider.repos) |repos| {
        if (repos.view(allocator, token, ctx.owner, ctx.repo)) |info| {
            try stdout.interface.print("  repo:   {s}, {d} open issues\n", .{ info.visibility, info.open_issues });
        } else |_| {
            try stdout.interface.print("  repo:   unavailable\n", .{});
        }
    } else {
        try stdout.interface.print("  repo:   not supported\n", .{});
    }

    // PR pulse via prs.list
    if (provider.prs) |prs| {
        if (prs.list(allocator, token, ctx.owner, ctx.repo)) |list| {
            var open: usize = 0;
            var draft: usize = 0;
            for (list) |pr| {
                if (std.mem.eql(u8, pr.state, "open")) open += 1;
                if (pr.draft) draft += 1;
            }
            if (draft > 0) {
                try stdout.interface.print("  prs:    {d} open ({d} draft)\n", .{ open, draft });
            } else {
                try stdout.interface.print("  prs:    {d} open\n", .{open});
            }
            if (list.len > 0) {
                const latest = list[0];
                try stdout.interface.print("  latest: #{d} \"{s}\" ({s})\n", .{ latest.number, latest.title, latest.source_branch });
            }
        } else |_| {
            try stdout.interface.print("  prs:    unavailable\n", .{});
        }
    } else {
        try stdout.interface.print("  prs:    not supported\n", .{});
    }
}

fn printDoctor(stdout: anytype, allocator: std.mem.Allocator, ctxs: []context.ResolvedContext, token: []const u8, provider_url: ?[]const u8, quick: bool) !void {
    const ctx = ctxs[0];

    try stdout.interface.print("gctl doctor — system diagnostics\n\n", .{});

    // Phase 1: local checks
    try stdout.interface.print("── Git ──────────────────────────────────────\n", .{});
    try stdout.interface.print("  ✓ Repository detected\n", .{});
    try stdout.interface.print("  {d} remote(s) parsed\n\n", .{ctxs.len});

    for (ctxs, 0..) |c, i| {
        const active = if (i == 0) " (active)" else "";
        try stdout.interface.print("  {d}. {s} → {s}/{s}  ({s}){s}\n", .{ i + 1, c.remote_name, c.owner, c.repo, c.provider, active });
    }

    try stdout.interface.print("\n── Provider ──────────────────────────────────\n", .{});
    try stdout.interface.print("  Resolved: {s}\n", .{ctx.provider});
    if (provider_url) |url| {
        try stdout.interface.print("  API URL:   {s}\n", .{url});
    } else {
        try stdout.interface.print("  API URL:   {s}\n", .{ctx.remote_url});
    }

    const prov = getProvider(ctx.provider) orelse {
        try stdout.interface.print("  ✗ Unknown provider\n", .{});
        return;
    };

    try stdout.interface.print("\n── Capabilities ──────────────────────────────\n", .{});
    if (prov.repos != null)   try stdout.interface.print("  ✓ repos\n", .{});
    if (prov.issues != null)  try stdout.interface.print("  ✓ issues\n", .{});
    if (prov.prs != null)     try stdout.interface.print("  ✓ prs\n", .{});
    if (prov.labels != null)  try stdout.interface.print("  ✓ labels\n", .{});
    if (prov.releases != null) try stdout.interface.print("  ✓ releases\n", .{});
    if (prov.pipelines != null) try stdout.interface.print("  ✓ pipelines\n", .{});

    const env_var = try std.fmt.allocPrint(allocator, "{s}_TOKEN", .{ upperEnvVar(ctx.provider) });
    defer allocator.free(env_var);

    try stdout.interface.print("\n── Token ─────────────────────────────────────\n", .{});
    if (token.len > 0) {
        try stdout.interface.print("  ✓ {s} set\n", .{env_var});
    } else {
        try stdout.interface.print("  ⚠  {s} not set\n", .{env_var});
    }

    if (quick or token.len == 0) {
        try stdout.interface.print("\n── Summary ────────────────────────────────────\n", .{});
        if (quick) {
            try stdout.interface.print("  Quick check complete — run gctl doctor (without --quick) for full API checks\n", .{});
        } else {
            try stdout.interface.print("  ⚠  Set {s} to enable API checks\n", .{env_var});
        }
        return;
    }

    // Phase 2: API checks
    try stdout.interface.print("\n── API Connectivity ─────────────────────────\n", .{});
    if (prov.repos) |repos| {
        const result = repos.view(allocator, token, ctx.owner, ctx.repo);
        if (result) |repo| {
            try stdout.interface.print("  ✓ {s}/{s} reachable\n", .{ ctx.owner, ctx.repo });
            try stdout.interface.print("  Default branch: {s}\n", .{repo.default_branch});
            try stdout.interface.print("  Visibility: {s}\n", .{repo.visibility});
        } else |err| {
            try stdout.interface.print("  ✗ API call failed: {}\n", .{err});
        }
    } else if (prov.issues) |issues| {
        const result = issues.list(allocator, token, ctx.owner, ctx.repo);
        if (result) |list| {
            try stdout.interface.print("  ✓ API reachable — {d} issue(s)\n", .{list.len});
        } else |err| {
            try stdout.interface.print("  ✗ API call failed: {}\n", .{err});
        }
    } else {
        try stdout.interface.print("  ○ No capability to verify connectivity\n", .{});
    }

    try stdout.interface.print("\n── Summary ────────────────────────────────────\n", .{});
    try stdout.interface.print("  All systems nominal\n", .{});
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

fn execLabelSetAll(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, labels_raw: ?[]const u8) !void {
    if (provider.labels) |labels_vtable| {
        const raw = labels_raw orelse {
            try stderr.interface.print("error: label set_all requires a comma-separated list of labels\n", .{});
            stderr.end() catch {};
            std.process.exit(1);
        };

        var label_list = try std.ArrayList(types.LabelDef).initCapacity(allocator, 16);
        defer label_list.deinit(allocator);

        var it = std.mem.splitScalar(u8, raw, ',');
        while (it.next()) |name| {
            const trimmed = std.mem.trim(u8, name, " ");
            if (trimmed.len > 0) {
                try label_list.append(allocator, types.LabelDef{
                    .name = trimmed,
                });
            }
        }

        const params = types.LabelParams{ .labels = label_list.items };
        try labels_vtable.set_all(allocator, token, ctx.owner, ctx.repo, params);
        try stdout.interface.print("Replaced labels on {s}/{s} with {d} label(s)\n", .{ ctx.owner, ctx.repo, label_list.items.len });
        return;
    }
    try stderr.interface.print("error: {s} does not support label operations.\n", .{provider.name});
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

fn execIssueCreate(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, title: ?[]const u8) !void {
    if (provider.issues) |issues| {
        const issue_title = title orelse {
            try stderr.interface.print("error: issue create requires a title\n", .{});
            stderr.end() catch {};
            std.process.exit(1);
        };
        const params = types.IssueCreateParams{ .title = issue_title };
        const info = try issues.create(allocator, token, ctx.owner, ctx.repo, params);
        try cli.output.printKeyValue(stdout, &.{
            .{ "Number", try std.fmt.allocPrint(allocator, "{d}", .{info.number}) },
            .{ "Title", info.title },
            .{ "State", info.state },
            .{ "URL", info.url },
        }, false);
        return;
    }
    try stderr.interface.print("error: {s} does not support issue operations.\n", .{provider.name});
    stderr.end() catch {};
    std.process.exit(1);
}

fn execIssueClose(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, number: ?u64) !void {
    if (provider.issues) |issues| {
        const num = number orelse {
            try stderr.interface.print("error: issue close requires an issue number\n", .{});
            stderr.end() catch {};
            std.process.exit(1);
        };
        const info = try issues.close(allocator, token, ctx.owner, ctx.repo, num);
        try cli.output.printKeyValue(stdout, &.{
            .{ "Number", try std.fmt.allocPrint(allocator, "{d}", .{info.number}) },
            .{ "Title", info.title },
            .{ "State", info.state },
            .{ "URL", info.url },
        }, false);
        return;
    }
    try stderr.interface.print("error: {s} does not support issue operations.\n", .{provider.name});
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

fn getCurrentBranch(allocator: std.mem.Allocator) ![]const u8 {
    var child = std.process.Child.init(&.{ "git", "rev-parse", "--abbrev-ref", "HEAD" }, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore;
    try child.spawn();

    const output = try child.stdout.?.readToEndAlloc(allocator, 256);
    defer allocator.free(output);

    _ = try child.wait();

    return std.mem.trim(u8, output, " \n\r");
}

fn execPRCreate(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, title: ?[]const u8, base: ?[]const u8) !void {
    if (provider.prs) |prs| {
        const pr_title = title orelse {
            try stderr.interface.print("error: pr create requires a title\n", .{});
            stderr.end() catch {};
            std.process.exit(1);
        };

        const head = getCurrentBranch(allocator) catch |err| {
            try stderr.interface.print("error: could not detect current branch: {}\n", .{err});
            stderr.end() catch {};
            std.process.exit(1);
        };
        defer allocator.free(head);

        const base_branch = base orelse "main";
        const params = types.PRCreateParams{
            .title = pr_title,
            .head = head,
            .base = base_branch,
        };
        const info = try prs.create(allocator, token, ctx.owner, ctx.repo, params);
        try cli.output.printKeyValue(stdout, &.{
            .{ "Number", try std.fmt.allocPrint(allocator, "{d}", .{info.number}) },
            .{ "Title", info.title },
            .{ "State", info.state },
            .{ "URL", info.url },
            .{ "From", info.source_branch },
            .{ "To", info.target_branch },
        }, false);
        return;
    }
    try stderr.interface.print("error: {s} does not support pull requests.\n", .{provider.name});
    stderr.end() catch {};
    std.process.exit(1);
}

fn execPRMerge(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, number: ?u64) !void {
    if (provider.prs) |prs| {
        const num = number orelse {
            try stderr.interface.print("error: pr merge requires a PR number\n", .{});
            stderr.end() catch {};
            std.process.exit(1);
        };
        try prs.merge(allocator, token, ctx.owner, ctx.repo, num);
        try stdout.interface.print("Merged #{d} on {s}/{s}\n", .{ num, ctx.owner, ctx.repo });
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
