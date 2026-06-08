const std = @import("std");
const types = @import("types.zig");
const http = @import("http");

const BASE_URL = "https://api.github.com";

// ── JSON helpers ───────────────────────────────────────────────────────────

fn getString(obj: std.json.ObjectMap, key: []const u8) []const u8 {
    return if (obj.get(key)) |v| v.string else "";
}

fn getU64(obj: std.json.ObjectMap, key: []const u8) u64 {
    return if (obj.get(key)) |v| @intCast(v.integer) else 0;
}

fn getBool(obj: std.json.ObjectMap, key: []const u8) bool {
    return if (obj.get(key)) |v| v.bool else false;
}

fn getStringArray(allocator: std.mem.Allocator, obj: std.json.ObjectMap, key: []const u8) ![]const []const u8 {
    const arr = obj.get(key) orelse return &[_][]const u8{};
    if (arr.array.items.len == 0) return &[_][]const u8{};

    var list = std.ArrayList([]const u8).init(allocator);
    for (arr.array.items) |item| {
        try list.append(allocator, item.string);
    }
    return list.toOwnedSlice(allocator);
}

// ── Shared request helper ──────────────────────────────────────────────────

fn apiGet(allocator: std.mem.Allocator, token: []const u8, path: []const u8) !std.json.Parsed(std.json.Value) {
    const url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ BASE_URL, path });
    defer allocator.free(url);

    const resp = try http.client.get(allocator, url, token);
    defer allocator.free(resp.body);

    if (resp.status < 200 or resp.status >= 300) {
        std.log.err("GitHub API returned {d}: {s}", .{ resp.status, resp.body });
        return error.HttpError;
    }

    return std.json.parseFromSlice(std.json.Value, allocator, resp.body, .{ .allocate = .alloc_always });
}

// ── Repository ─────────────────────────────────────────────────────────────

fn repoView(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8) !types.RepoInfo {
    const path = try std.fmt.allocPrint(allocator, "/repos/{s}/{s}", .{ owner, repo });
    defer allocator.free(path);

    var parsed = try apiGet(allocator, token, path);
    defer parsed.deinit();

    const obj = parsed.value.object;
    return types.RepoInfo{
        .name = getString(obj, "name"),
        .full_name = getString(obj, "full_name"),
        .description = getString(obj, "description"),
        .url = getString(obj, "html_url"),
        .default_branch = getString(obj, "default_branch"),
        .stars = getU64(obj, "stargazers_count"),
        .forks = getU64(obj, "forks_count"),
        .open_issues = getU64(obj, "open_issues_count"),
        .visibility = getString(obj, "visibility"),
    };
}

pub const repo_vtable: types.RepoVtable = .{ .view = repoView };

// ── Issues ─────────────────────────────────────────────────────────────────

fn issueList(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8) ![]types.IssueInfo {
    const path = try std.fmt.allocPrint(allocator, "/repos/{s}/{s}/issues?state=open&per_page=30", .{ owner, repo });
    defer allocator.free(path);

    var parsed = try apiGet(allocator, token, path);
    defer parsed.deinit();

    const arr = parsed.value.array.items;
    var list = try std.ArrayList(types.IssueInfo).initCapacity(allocator, arr.len);

    for (arr) |item| {
        const obj = item.object;
        // Skip pull requests (they have pull_request field)
        if (obj.get("pull_request") != null) continue;

        // Extract label names from [{name: ...}, ...]
        var label_names = try std.ArrayList([]const u8).initCapacity(allocator, 4);
        if (obj.get("labels")) |labels_val| {
            for (labels_val.array.items) |lbl| {
                const lbl_obj = lbl.object;
                try label_names.append(allocator, getString(lbl_obj, "name"));
            }
        }

        try list.append(allocator, types.IssueInfo{
            .number = getU64(obj, "number"),
            .title = getString(obj, "title"),
            .state = getString(obj, "state"),
            .author = if (obj.get("user")) |u| getString(u.object, "login") else "",
            .labels = try label_names.toOwnedSlice(allocator),
            .url = getString(obj, "html_url"),
            .created_at = getString(obj, "created_at"),
            .body = getString(obj, "body"),
        });
    }

    return list.toOwnedSlice(allocator);
}

fn issueView(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, number: u64) !types.IssueInfo {
    const path = try std.fmt.allocPrint(allocator, "/repos/{s}/{s}/issues/{d}", .{ owner, repo, number });
    defer allocator.free(path);

    var parsed = try apiGet(allocator, token, path);
    defer parsed.deinit();

    const obj = parsed.value.object;

    var label_names = try std.ArrayList([]const u8).initCapacity(allocator, 4);
    if (obj.get("labels")) |labels_val| {
        for (labels_val.array.items) |lbl| {
            const lbl_obj = lbl.object;
            try label_names.append(allocator, getString(lbl_obj, "name"));
        }
    }

    return types.IssueInfo{
        .number = getU64(obj, "number"),
        .title = getString(obj, "title"),
        .state = getString(obj, "state"),
        .author = if (obj.get("user")) |u| getString(u.object, "login") else "",
        .labels = try label_names.toOwnedSlice(allocator),
        .url = getString(obj, "html_url"),
        .created_at = getString(obj, "created_at"),
        .body = getString(obj, "body"),
    };
}

pub const issue_vtable: types.IssueVtable = .{ .list = issueList, .view = issueView };

// ── Pull Requests ──────────────────────────────────────────────────────────

fn prList(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8) ![]types.PullRequestInfo {
    const path = try std.fmt.allocPrint(allocator, "/repos/{s}/{s}/pulls?state=open&per_page=30", .{ owner, repo });
    defer allocator.free(path);

    var parsed = try apiGet(allocator, token, path);
    defer parsed.deinit();

    const arr = parsed.value.array.items;
    var list = try std.ArrayList(types.PullRequestInfo).initCapacity(allocator, arr.len);

    for (arr) |item| {
        const obj = item.object;
        try list.append(allocator, types.PullRequestInfo{
            .number = getU64(obj, "number"),
            .title = getString(obj, "title"),
            .state = getString(obj, "state"),
            .author = if (obj.get("user")) |u| getString(u.object, "login") else "",
            .draft = getBool(obj, "draft"),
            .url = getString(obj, "html_url"),
            .created_at = getString(obj, "created_at"),
            .source_branch = if (obj.get("head")) |h| getString(h.object, "ref") else "",
            .target_branch = if (obj.get("base")) |b| getString(b.object, "ref") else "",
        });
    }

    return list.toOwnedSlice(allocator);
}

fn prView(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, number: u64) !types.PullRequestInfo {
    const path = try std.fmt.allocPrint(allocator, "/repos/{s}/{s}/pulls/{d}", .{ owner, repo, number });
    defer allocator.free(path);

    var parsed = try apiGet(allocator, token, path);
    defer parsed.deinit();

    const obj = parsed.value.object;
    return types.PullRequestInfo{
        .number = getU64(obj, "number"),
        .title = getString(obj, "title"),
        .state = getString(obj, "state"),
        .author = if (obj.get("user")) |u| getString(u.object, "login") else "",
        .draft = getBool(obj, "draft"),
        .url = getString(obj, "html_url"),
        .created_at = getString(obj, "created_at"),
        .source_branch = if (obj.get("head")) |h| getString(h.object, "ref") else "",
        .target_branch = if (obj.get("base")) |b| getString(b.object, "ref") else "",
    };
}

pub const pr_vtable: types.PRVtable = .{ .list = prList, .view = prView };

test {
    _ = repo_vtable;
    _ = issue_vtable;
    _ = pr_vtable;
}
