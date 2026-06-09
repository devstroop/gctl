const std = @import("std");
const types = @import("types.zig");
const github = @import("github.zig");
const gitlab = @import("gitlab.zig");
const gitea = @import("gitea.zig");
const context = @import("context");
const cli = @import("cli");
const http = @import("http");

// ── Provider registry ──────────────────────────────────────────────────────

const providers = [_]types.Provider{
    .{
        .name = "github",
        .base_url = "https://api.github.com",
        .repos = github.repo_vtable,
        .issues = github.issue_vtable,
        .prs = github.pr_vtable,
        .labels = github.label_vtable,
        .releases = null,
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
        .repos = gitea.repo_vtable,
        .issues = gitea.issue_vtable,
        .prs = gitea.pr_vtable,
        .labels = gitea.label_vtable,
        .releases = null,
        .pipelines = null,
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
    path: ?[]const u8,
    method: ?[]const u8,
    name: ?[]const u8,
    description: ?[]const u8,
    private: bool,
    labels: ?[]const u8,
    title: ?[]const u8,
    base: ?[]const u8,
    quick: bool,
    all: bool,
    source: ?[]const u8,
    target: ?[]const u8,
    json: bool,
) !void {
    if (ctxs.len == 0) {
        try stderr.interface.print("error: no context resolved\n", .{});
        stderr.end() catch {};
        std.process.exit(1);
    }

    // Network is purely local — no provider or token needed
    if (command == .network) {
        return printNetwork(stdout, ctxs, all, json);
    }

    const t = if (token) |tok| tok else "";
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
        try stderr.interface.print("Set {s}_TOKEN or run 'gitctl auth login {s}'.\n", .{ upperEnvVar(ctx.provider), ctx.provider });
        stderr.end() catch {};
        std.process.exit(1);
    }

    // Export/import — use current provider, path-based resource addressing
    if (command == .@"export") return execExport(stdout, stderr, allocator, ctxs, p, t, provider_url, path, json);
    if (command == .import) return execImport(stdout, stderr, allocator, ctxs, p, t, provider_url, path, json);

    switch (command) {
        .doctor => try printDoctor(stdout, allocator, ctxs, t, provider_url, quick, json),
        .status => try execPrintStatus(stdout, stderr, allocator, p, t, ctx, json),
        .repo_view => try execRepoView(allocator, stdout, stderr, p, t, ctx, json),
        .repo_create => try execRepoCreate(allocator, stdout, stderr, p, t, ctx, name, description, private, json),
        .repo_delete => try execRepoDelete(allocator, stdout, stderr, p, t, ctx, name, json),
        .repo_archive => try execRepoArchive(allocator, stdout, stderr, p, t, ctx, name, json),
        .label_set_all => try execLabelSetAll(allocator, stdout, stderr, p, t, ctx, labels, json),
        .issue_create => try execIssueCreate(allocator, stdout, stderr, p, t, ctx, title, json),
        .issue_close => try execIssueClose(allocator, stdout, stderr, p, t, ctx, number, json),
        .issue_list => try execIssueList(allocator, stdout, stderr, p, t, ctx, json),
        .issue_view => try execIssueView(allocator, stdout, stderr, p, t, ctx, number, json),
        .pr_create => try execPRCreate(allocator, stdout, stderr, p, t, ctx, title, base, json),
        .pr_merge => try execPRMerge(allocator, stdout, stderr, p, t, ctx, number, json),
        .pr_list => try execPRList(allocator, stdout, stderr, p, t, ctx, json),
        .pr_view => try execPRView(allocator, stdout, stderr, p, t, ctx, number, json),
        .@"export" => unreachable,
        .import => unreachable,
        .copy => try execCopy(stdout, stderr, allocator, ctxs, t, provider_url, source, target, json),
        .diff => try execDiff(stdout, stderr, allocator, ctxs, p, t, provider_url, source, target, json),
        .api => try execApi(stdout, stderr, allocator, p, t, provider_url, method, path, json),
        .network => unreachable,
        .auth_login => unreachable,
        .auth_logout => unreachable,
        .auth_list => unreachable,
        .auth_status => unreachable,
        .completion => unreachable,
    }
}

fn printNetwork(writer: anytype, ctxs: []context.ResolvedContext, verbose: bool, json: bool) !void {
    if (verbose) {
        const headers = [_][]const u8{ "#", "Remote", "Provider", "Owner", "Repo", "URL" };
        var rows = try std.ArrayList([]const []const u8).initCapacity(std.heap.page_allocator, ctxs.len);
        defer rows.deinit(std.heap.page_allocator);
        for (ctxs, 0..) |c, i| {
            const row = [_][]const u8{
                try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{i + 1}),
                c.remote_name,
                c.provider,
                c.owner,
                c.repo,
                c.remote_url,
            };
            try rows.append(std.heap.page_allocator, &row);
        }
        try cli.output.printTable(writer, &headers, rows.items, json);
        return;
    }

    // Compact: numbered list
    try writer.interface.print("Found {d} remote(s)\n\n", .{ctxs.len});
    for (ctxs, 0..) |c, i| {
        const active = if (i == 0) "  ← active" else "";
        try writer.interface.print("  {d}. {s:20} {s:8} {s}/{s}{s}\n", .{ i + 1, c.remote_name, c.provider, c.owner, c.repo, active });
    }
}

/// Parse a resource path like "issues/14" or "prs/42" into type string and optional id.
/// Returns .type, .id_str. Caller owns id_str (allocated) if non-null.
fn parseResourcePath(allocator: std.mem.Allocator, path: []const u8) !struct { resource_type: []const u8, id_str: ?[]const u8 } {
    var parts = std.mem.splitScalar(u8, path, '/');
    const resource_type = parts.next() orelse return error.InvalidArgument;
    const id_part = parts.next();
    return .{
        .resource_type = resource_type,
        .id_str = if (id_part) |id| try allocator.dupe(u8, id) else null,
    };
}

fn execExport(stdout: anytype, stderr: anytype, allocator: std.mem.Allocator, ctxs: []context.ResolvedContext, provider: *const types.Provider, token: []const u8, _: ?[]const u8, path: ?[]const u8, _: bool) !void {
    const ctx = ctxs[0];
    const resource_path = path orelse {
        try stderr.interface.print("error: export requires a resource path (e.g. issues/14)\n", .{});
        std.process.exit(1);
    };

    const parsed = parseResourcePath(allocator, resource_path) catch {
        try stderr.interface.print("error: invalid resource path '{s}'\n", .{resource_path});
        std.process.exit(1);
    };
    defer if (parsed.id_str) |id| allocator.free(id);

    const t = parsed.resource_type;
    if (std.mem.eql(u8, t, "issues")) {
        if (provider.issues) |vtable| {
            if (parsed.id_str) |id| {
                const num = std.fmt.parseUnsigned(u64, id, 10) catch {
                    try stderr.interface.print("error: invalid issue number '{s}'\n", .{id});
                    std.process.exit(1);
                };
                const info = try vtable.view(allocator, token, ctx.owner, ctx.repo, num);
                try std.json.Stringify.value(info, .{}, &stdout.interface);
                try stdout.interface.writeAll("\n");
            }
        } else {
            try stderr.interface.print("error: issues not supported on {s}\n", .{ctx.provider});
            std.process.exit(1);
        }
    } else if (std.mem.eql(u8, t, "prs")) {
        if (provider.prs) |vtable| {
            if (parsed.id_str) |id| {
                const num = std.fmt.parseUnsigned(u64, id, 10) catch {
                    try stderr.interface.print("error: invalid PR number '{s}'\n", .{id});
                    std.process.exit(1);
                };
                const info = try vtable.view(allocator, token, ctx.owner, ctx.repo, num);
                try std.json.Stringify.value(info, .{}, &stdout.interface);
                try stdout.interface.writeAll("\n");
            }
        } else {
            try stderr.interface.print("error: pull requests not supported on {s}\n", .{ctx.provider});
            std.process.exit(1);
        }
    } else {
        try stderr.interface.print("error: unknown resource type '{s}'\n", .{t});
        std.process.exit(1);
    }
}

fn execImport(stdout: anytype, stderr: anytype, allocator: std.mem.Allocator, ctxs: []context.ResolvedContext, provider: *const types.Provider, token: []const u8, _: ?[]const u8, path: ?[]const u8, _: bool) !void {
    const ctx = ctxs[0];
    const resource_path = path orelse {
        try stderr.interface.print("error: import requires a resource path (e.g. issues/)\n", .{});
        std.process.exit(1);
    };

    const parsed = parseResourcePath(allocator, resource_path) catch {
        try stderr.interface.print("error: invalid resource path '{s}'\n", .{resource_path});
        std.process.exit(1);
    };
    defer if (parsed.id_str) |id| allocator.free(id);

    // Read all of stdin
    const stdin_raw = std.fs.File.stdin();
    const json_bytes = try stdin_raw.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(json_bytes);

    const t = parsed.resource_type;
    if (std.mem.eql(u8, t, "issues")) {
        if (provider.issues) |vtable| {
            const info = try std.json.parseFromSlice(types.IssueInfo, allocator, json_bytes, .{});
            defer info.deinit();
            const params = types.IssueCreateParams{
                .title = info.value.title,
                .body = info.value.body,
            };
            const created = try vtable.create(allocator, token, ctx.owner, ctx.repo, params);
            try stdout.interface.print("Created issue #{d}: {s}\n", .{ created.number, created.title });
        } else {
            try stderr.interface.print("error: issues not supported on {s}\n", .{ctx.provider});
            std.process.exit(1);
        }
    } else if (std.mem.eql(u8, t, "prs")) {
        if (provider.prs) |vtable| {
            const info = try std.json.parseFromSlice(types.PullRequestInfo, allocator, json_bytes, .{});
            defer info.deinit();
            const params = types.PRCreateParams{
                .title = info.value.title,
                .head = info.value.source_branch,
                .base = info.value.target_branch,
            };
            const created = try vtable.create(allocator, token, ctx.owner, ctx.repo, params);
            try stdout.interface.print("Created PR #{d}: {s}\n", .{ created.number, created.title });
        } else {
            try stderr.interface.print("error: pull requests not supported on {s}\n", .{ctx.provider});
            std.process.exit(1);
        }
    } else {
        try stderr.interface.print("error: unknown resource type '{s}'\n", .{t});
        std.process.exit(1);
    }
}

fn execCopy(stdout: anytype, stderr: anytype, allocator: std.mem.Allocator, ctxs: []context.ResolvedContext, token: []const u8, _: ?[]const u8, source: ?[]const u8, target: ?[]const u8, _: bool) !void {
    const src_path = source orelse {
        try stderr.interface.print("error: copy requires a source path (e.g. issues/14)\n", .{});
        std.process.exit(1);
    };
    const tgt_remote = target orelse {
        try stderr.interface.print("error: copy requires a target remote (e.g. upstream)\n", .{});
        std.process.exit(1);
    };

    // Find target context
    const tgt_ctx = blk: {
        for (ctxs) |c| {
            if (std.mem.eql(u8, c.remote_name, tgt_remote)) break :blk c;
        }
        try stderr.interface.print("error: remote '{s}' not found\n", .{tgt_remote});
        std.process.exit(1);
    };

    const tgt_provider = getProvider(tgt_ctx.provider) orelse {
        try stderr.interface.print("error: unknown provider '{s}'\n", .{tgt_ctx.provider});
        std.process.exit(1);
    };

    // Parse source path
    const parsed = parseResourcePath(allocator, src_path) catch {
        try stderr.interface.print("error: invalid source path '{s}'\n", .{src_path});
        std.process.exit(1);
    };
    defer if (parsed.id_str) |id| allocator.free(id);

    const src_ctx = ctxs[0];
    const src_provider = getProvider(src_ctx.provider) orelse {
        try stderr.interface.print("error: unknown source provider\n", .{});
        std.process.exit(1);
    };

    const t = parsed.resource_type;
    if (std.mem.eql(u8, t, "issues")) {
        if (src_provider.issues == null) {
            try stderr.interface.print("error: issues not supported on source\n", .{});
            std.process.exit(1);
        }
        if (tgt_provider.issues == null) {
            try stderr.interface.print("error: issues not supported on target '{s}'\n", .{tgt_remote});
            std.process.exit(1);
        }
        const num = std.fmt.parseUnsigned(u64, parsed.id_str orelse {
            try stderr.interface.print("error: source path must include an issue number\n", .{});
            std.process.exit(1);
        }, 10) catch {
            try stderr.interface.print("error: invalid issue number\n", .{});
            std.process.exit(1);
        };
        const info = try src_provider.issues.?.view(allocator, token, src_ctx.owner, src_ctx.repo, num);
        const params = types.IssueCreateParams{
            .title = info.title,
            .body = info.body,
        };
        const created = try tgt_provider.issues.?.create(allocator, token, tgt_ctx.owner, tgt_ctx.repo, params);
        try stdout.interface.print("Copied issue #{d} → {s} #{d}\n", .{ num, tgt_remote, created.number });
    } else if (std.mem.eql(u8, t, "prs")) {
        if (src_provider.prs == null) {
            try stderr.interface.print("error: PRs not supported on source\n", .{});
            std.process.exit(1);
        }
        if (tgt_provider.prs == null) {
            try stderr.interface.print("error: PRs not supported on target '{s}'\n", .{tgt_remote});
            std.process.exit(1);
        }
        const num = std.fmt.parseUnsigned(u64, parsed.id_str orelse {
            try stderr.interface.print("error: source path must include a PR number\n", .{});
            std.process.exit(1);
        }, 10) catch {
            try stderr.interface.print("error: invalid PR number\n", .{});
            std.process.exit(1);
        };
        const info = try src_provider.prs.?.view(allocator, token, src_ctx.owner, src_ctx.repo, num);
        const params = types.PRCreateParams{
            .title = info.title,
            .head = info.source_branch,
            .base = info.target_branch,
        };
        const created = try tgt_provider.prs.?.create(allocator, token, tgt_ctx.owner, tgt_ctx.repo, params);
        try stdout.interface.print("Copied PR #{d} → {s} #{d}\n", .{ num, tgt_remote, created.number });
    } else {
        try stderr.interface.print("error: unknown resource type '{s}'\n", .{t});
        std.process.exit(1);
    }
}

fn diffIssue(stdout: anytype, a: types.IssueInfo, b: types.IssueInfo) !void {
    try stdout.interface.print("Comparing issue #{d}:\n\n", .{a.number});
    if (!std.mem.eql(u8, a.title, b.title)) {
        try stdout.interface.print("  title:\n    - \"{s}\"\n    + \"{s}\"\n", .{ a.title, b.title });
    }
    if (!std.mem.eql(u8, a.state, b.state)) {
        try stdout.interface.print("  state:  {s} vs {s}\n", .{ a.state, b.state });
    }
    if (!std.mem.eql(u8, a.author, b.author)) {
        try stdout.interface.print("  author: {s} vs {s}\n", .{ a.author, b.author });
    }
    if (!std.mem.eql(u8, a.body, b.body)) {
        try stdout.interface.print("  body:   (different)\n", .{});
    }
    // Labels comparison
    {
        var same_labels = a.labels.len == b.labels.len;
        if (same_labels) {
            for (a.labels, b.labels) |la, lb| {
                if (!std.mem.eql(u8, la, lb)) {
                    same_labels = false;
                    break;
                }
            }
        }
        if (!same_labels) {
            try stdout.interface.print("  labels:\n", .{});
            try stdout.interface.print("    -", .{});
            for (a.labels) |l| try stdout.interface.print(" \"{s}\"", .{l});
            try stdout.interface.print("\n", .{});
            try stdout.interface.print("    +", .{});
            for (b.labels) |l| try stdout.interface.print(" \"{s}\"", .{l});
            try stdout.interface.print("\n", .{});
        }
    }
}

fn diffPR(stdout: anytype, a: types.PullRequestInfo, b: types.PullRequestInfo) !void {
    try stdout.interface.print("Comparing PR #{d}:\n\n", .{a.number});
    if (!std.mem.eql(u8, a.title, b.title)) {
        try stdout.interface.print("  title:\n    - \"{s}\"\n    + \"{s}\"\n", .{ a.title, b.title });
    }
    if (!std.mem.eql(u8, a.state, b.state)) {
        try stdout.interface.print("  state:  {s} vs {s}\n", .{ a.state, b.state });
    }
    if (!std.mem.eql(u8, a.author, b.author)) {
        try stdout.interface.print("  author: {s} vs {s}\n", .{ a.author, b.author });
    }
    if (a.draft != b.draft) {
        try stdout.interface.print("  draft:  {} vs {}\n", .{ a.draft, b.draft });
    }
    if (!std.mem.eql(u8, a.source_branch, b.source_branch)) {
        try stdout.interface.print("  source_branch:  {s} vs {s}\n", .{ a.source_branch, b.source_branch });
    }
    if (!std.mem.eql(u8, a.target_branch, b.target_branch)) {
        try stdout.interface.print("  target_branch:  {s} vs {s}\n", .{ a.target_branch, b.target_branch });
    }
}

fn execDiff(stdout: anytype, stderr: anytype, allocator: std.mem.Allocator, ctxs: []context.ResolvedContext, provider: *const types.Provider, token: []const u8, _: ?[]const u8, source: ?[]const u8, target: ?[]const u8, _: bool) !void {
    const src_path = source orelse {
        try stderr.interface.print("error: diff requires a source path (e.g. issues/14)\n", .{});
        std.process.exit(1);
    };
    const tgt_remote = target orelse {
        try stderr.interface.print("error: diff requires a target remote (e.g. upstream)\n", .{});
        std.process.exit(1);
    };

    // Find target context
    const tgt_ctx = blk: {
        for (ctxs) |c| {
            if (std.mem.eql(u8, c.remote_name, tgt_remote)) break :blk c;
        }
        try stderr.interface.print("error: remote '{s}' not found\n", .{tgt_remote});
        std.process.exit(1);
    };

    const tgt_provider = getProvider(tgt_ctx.provider) orelse {
        try stderr.interface.print("error: unknown provider '{s}'\n", .{tgt_ctx.provider});
        std.process.exit(1);
    };

    // Parse source path
    const parsed = parseResourcePath(allocator, src_path) catch {
        try stderr.interface.print("error: invalid source path '{s}'\n", .{src_path});
        std.process.exit(1);
    };
    defer if (parsed.id_str) |id| allocator.free(id);

    const src_ctx = ctxs[0];

    const t = parsed.resource_type;
    if (std.mem.eql(u8, t, "issues")) {
        if (provider.issues == null) {
            try stderr.interface.print("error: issues not supported\n", .{});
            std.process.exit(1);
        }
        if (tgt_provider.issues == null) {
            try stderr.interface.print("error: issues not supported on '{s}'\n", .{tgt_remote});
            std.process.exit(1);
        }
        const num = std.fmt.parseUnsigned(u64, parsed.id_str orelse {
            try stderr.interface.print("error: source path must include an issue number\n", .{});
            std.process.exit(1);
        }, 10) catch {
            try stderr.interface.print("error: invalid issue number\n", .{});
            std.process.exit(1);
        };
        const a = try provider.issues.?.view(allocator, token, src_ctx.owner, src_ctx.repo, num);
        const b = try tgt_provider.issues.?.view(allocator, token, tgt_ctx.owner, tgt_ctx.repo, num);
        try diffIssue(stdout, a, b);
    } else if (std.mem.eql(u8, t, "prs")) {
        if (provider.prs == null) {
            try stderr.interface.print("error: PRs not supported\n", .{});
            std.process.exit(1);
        }
        if (tgt_provider.prs == null) {
            try stderr.interface.print("error: PRs not supported on '{s}'\n", .{tgt_remote});
            std.process.exit(1);
        }
        const num = std.fmt.parseUnsigned(u64, parsed.id_str orelse {
            try stderr.interface.print("error: source path must include a PR number\n", .{});
            std.process.exit(1);
        }, 10) catch {
            try stderr.interface.print("error: invalid PR number\n", .{});
            std.process.exit(1);
        };
        const a = try provider.prs.?.view(allocator, token, src_ctx.owner, src_ctx.repo, num);
        const b = try tgt_provider.prs.?.view(allocator, token, tgt_ctx.owner, tgt_ctx.repo, num);
        try diffPR(stdout, a, b);
    } else {
        try stderr.interface.print("error: unknown resource type '{s}'\n", .{t});
        std.process.exit(1);
    }
}

fn execApi(stdout: anytype, stderr: anytype, allocator: std.mem.Allocator, provider: *const types.Provider, token: []const u8, provider_url: ?[]const u8, method: ?[]const u8, api_path: ?[]const u8, _: bool) !void {
    const m = method orelse {
        try stderr.interface.print("error: api requires an HTTP method (e.g. GET /repos/owner/repo)\n", .{});
        std.process.exit(1);
    };
    const p = api_path orelse {
        try stderr.interface.print("error: api requires a path (e.g. /repos/owner/repo)\n", .{});
        std.process.exit(1);
    };

    // Map method string to std.http.Method
    const method_enum = parseHttpMethod(m) orelse {
        try stderr.interface.print("error: unsupported HTTP method '{s}'\n", .{m});
        std.process.exit(1);
    };

    // Construct URL
    const base_url = provider_url orelse provider.base_url;
    const url = if (std.mem.startsWith(u8, p, "http"))
        p
    else if (std.mem.startsWith(u8, p, "/"))
        try std.fmt.allocPrint(allocator, "{s}{s}", .{ base_url, p })
    else
        try std.fmt.allocPrint(allocator, "{s}/{s}", .{ base_url, p });
    defer if (!std.mem.startsWith(u8, p, "http")) allocator.free(url);

    // Read stdin body for methods that support it
    const body = if (methodSupportsBody(method_enum)) blk: {
        const stdin_raw = std.fs.File.stdin();
        break :blk stdin_raw.readToEndAlloc(allocator, 1024 * 1024) catch null;
    } else null;
    defer if (body) |b| allocator.free(b);

    // Make the request
    const resp = switch (method_enum) {
        .GET => try http.get(allocator, url, token),
        .POST => try http.post(allocator, url, token, body orelse ""),
        .PUT => try http.put(allocator, url, token, body orelse ""),
        .PATCH => try http.patch(allocator, url, token, body orelse ""),
        .DELETE => try http.delete(allocator, url, token),
        else => {
            try stderr.interface.print("error: method not implemented\n", .{});
            std.process.exit(1);
        },
    };
    defer allocator.free(resp.body);

    // Print response
    try stdout.interface.print("HTTP {d}\n\n", .{resp.status});
    try stdout.interface.writeAll(resp.body);
    if (resp.body.len > 0 and resp.body[resp.body.len - 1] != '\n') {
        try stdout.interface.writeAll("\n");
    }
}

fn parseHttpMethod(s: []const u8) ?std.http.Method {
    if (std.ascii.eqlIgnoreCase(s, "GET")) return .GET;
    if (std.ascii.eqlIgnoreCase(s, "POST")) return .POST;
    if (std.ascii.eqlIgnoreCase(s, "PUT")) return .PUT;
    if (std.ascii.eqlIgnoreCase(s, "PATCH")) return .PATCH;
    if (std.ascii.eqlIgnoreCase(s, "DELETE")) return .DELETE;
    if (std.ascii.eqlIgnoreCase(s, "HEAD")) return .HEAD;
    if (std.ascii.eqlIgnoreCase(s, "OPTIONS")) return .OPTIONS;
    return null;
}

fn methodSupportsBody(m: std.http.Method) bool {
    return switch (m) {
        .POST, .PUT, .PATCH => true,
        else => false,
    };
}

fn execPrintStatus(stdout: anytype, _: anytype, allocator: std.mem.Allocator, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, _: bool) !void {
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

fn printDoctor(stdout: anytype, allocator: std.mem.Allocator, ctxs: []context.ResolvedContext, token: []const u8, provider_url: ?[]const u8, quick: bool, _: bool) !void {
    const ctx = ctxs[0];

    try stdout.interface.print("gitctl doctor — system diagnostics\n\n", .{});

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
    if (prov.repos != null) try stdout.interface.print("  ✓ repos\n", .{});
    if (prov.issues != null) try stdout.interface.print("  ✓ issues\n", .{});
    if (prov.prs != null) try stdout.interface.print("  ✓ prs\n", .{});
    if (prov.labels != null) try stdout.interface.print("  ✓ labels\n", .{});
    if (prov.releases != null) try stdout.interface.print("  ✓ releases\n", .{});
    if (prov.pipelines != null) try stdout.interface.print("  ✓ pipelines\n", .{});

    const env_var = try std.fmt.allocPrint(allocator, "{s}_TOKEN", .{upperEnvVar(ctx.provider)});
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
            try stdout.interface.print("  Quick check complete — run gitctl doctor (without --quick) for full API checks\n", .{});
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

fn execRepoCreate(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, name: ?[]const u8, description: ?[]const u8, private: bool, json: bool) !void {
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
        }, json);
        return;
    }
    try stderr.interface.print("error: {s} does not support repository creation.\n", .{provider.name});
    stderr.end() catch {};
    std.process.exit(1);
}

fn execRepoDelete(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, name: ?[]const u8, _: bool) !void {
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

fn execRepoArchive(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, name: ?[]const u8, json: bool) !void {
    if (provider.repos) |repos| {
        const repo_name = name orelse {
            try stderr.interface.print("error: repo archive requires a name\n", .{});
            stderr.end() catch {};
            std.process.exit(1);
        };
        const info = try repos.archive(allocator, token, ctx.owner, repo_name, true);
        try cli.output.printKeyValue(stdout, &.{
            .{ "Name", info.name },
            .{ "Archived", "yes" },
            .{ "URL", info.url },
        }, json);
        return;
    }
    try stderr.interface.print("error: {s} does not support repository archiving.\n", .{provider.name});
    stderr.end() catch {};
    std.process.exit(1);
}

fn execLabelSetAll(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, labels_raw: ?[]const u8, _: bool) !void {
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

fn execRepoView(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, json: bool) !void {
    if (provider.repos) |repos| {
        const info = try repos.view(allocator, token, ctx.owner, ctx.repo);
        try cli.output.printKeyValue(stdout, &.{
            .{ "Name", info.name },
            .{ "Full name", info.full_name },
            .{ "Description", info.description },
            .{ "URL", info.url },
            .{ "Default branch", info.default_branch },
            .{ "Visibility", info.visibility },
        }, json);
        return;
    }
    try stderr.interface.print("error: {s} does not support repository operations.\n", .{provider.name});
    stderr.end() catch {};
    std.process.exit(1);
}

fn execIssueList(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, json: bool) !void {
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
        try cli.output.printTable(stdout, &headers, rows.items, json);
        return;
    }
    try stderr.interface.print("error: {s} does not support issues.\n", .{provider.name});
    stderr.end() catch {};
    std.process.exit(1);
}

fn execIssueCreate(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, title: ?[]const u8, json: bool) !void {
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
        }, json);
        return;
    }
    try stderr.interface.print("error: {s} does not support issue operations.\n", .{provider.name});
    stderr.end() catch {};
    std.process.exit(1);
}

fn execIssueClose(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, number: ?u64, json: bool) !void {
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
        }, json);
        return;
    }
    try stderr.interface.print("error: {s} does not support issue operations.\n", .{provider.name});
    stderr.end() catch {};
    std.process.exit(1);
}

fn execIssueView(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, number: ?u64, json: bool) !void {
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
        }, json);
        try stdout.interface.print("\n{s}\n", .{info.body});
        return;
    }
    try stderr.interface.print("error: {s} does not support issues.\n", .{provider.name});
    stderr.end() catch {};
    std.process.exit(1);
}

fn execPRList(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, json: bool) !void {
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
        try cli.output.printTable(stdout, &headers, rows.items, json);
        return;
    }
    try stderr.interface.print("error: {s} does not support pull requests.\n", .{provider.name});
    stderr.end() catch {};
    std.process.exit(1);
}

fn execPRView(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, number: ?u64, json: bool) !void {
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
        }, json);
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

fn execPRCreate(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, title: ?[]const u8, base: ?[]const u8, json: bool) !void {
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
        }, json);
        return;
    }
    try stderr.interface.print("error: {s} does not support pull requests.\n", .{provider.name});
    stderr.end() catch {};
    std.process.exit(1);
}

fn execPRMerge(allocator: std.mem.Allocator, stdout: anytype, stderr: anytype, provider: *const types.Provider, token: []const u8, ctx: context.ResolvedContext, number: ?u64, _: bool) !void {
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
