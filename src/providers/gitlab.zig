const std = @import("std");
const types = @import("types.zig");
const http = @import("http");

const BASE_URL = "https://gitlab.com/api/v4";

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

// ── API helpers ────────────────────────────────────────────────────────────

/// GitLab uses URL-encoded project paths: "owner/repo" → "owner%2Frepo"
fn encodeProjectPath(allocator: std.mem.Allocator, owner: []const u8, repo: []const u8) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "{s}%2F{s}", .{ owner, repo });
}

fn apiGet(allocator: std.mem.Allocator, token: []const u8, path: []const u8) !std.json.Parsed(std.json.Value) {
    const url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ BASE_URL, path });
    defer allocator.free(url);

    const resp = try http.client.get(allocator, url, token);
    defer allocator.free(resp.body);

    if (resp.status < 200 or resp.status >= 300) {
        std.log.err("GitLab API returned {d}: {s}", .{ resp.status, resp.body });
        return error.HttpError;
    }

    return std.json.parseFromSlice(std.json.Value, allocator, resp.body, .{ .allocate = .alloc_always });
}

fn apiPost(allocator: std.mem.Allocator, token: []const u8, path: []const u8, body: []const u8) !std.json.Parsed(std.json.Value) {
    const url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ BASE_URL, path });
    defer allocator.free(url);

    const resp = try http.client.post(allocator, url, token, body);
    defer allocator.free(resp.body);

    if (resp.status < 200 or resp.status >= 300) {
        std.log.err("GitLab API returned {d}: {s}", .{ resp.status, resp.body });
        return error.HttpError;
    }

    return std.json.parseFromSlice(std.json.Value, allocator, resp.body, .{ .allocate = .alloc_always });
}

fn apiPut(allocator: std.mem.Allocator, token: []const u8, path: []const u8, body: []const u8) !std.json.Parsed(std.json.Value) {
    const url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ BASE_URL, path });
    defer allocator.free(url);

    const resp = try http.client.put(allocator, url, token, body);
    defer allocator.free(resp.body);

    if (resp.status < 200 or resp.status >= 300) {
        std.log.err("GitLab API returned {d}: {s}", .{ resp.status, resp.body });
        return error.HttpError;
    }

    return std.json.parseFromSlice(std.json.Value, allocator, resp.body, .{ .allocate = .alloc_always });
}

// ── Repository ─────────────────────────────────────────────────────────────

fn repoView(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8) !types.RepoInfo {
    const encoded = try encodeProjectPath(allocator, owner, repo);
    defer allocator.free(encoded);

    const path = try std.fmt.allocPrint(allocator, "/projects/{s}", .{encoded});
    defer allocator.free(path);

    var parsed = try apiGet(allocator, token, path);
    defer parsed.deinit();

    const obj = parsed.value.object;
    return types.RepoInfo{
        .name = getString(obj, "name"),
        .full_name = getString(obj, "name_with_namespace"),
        .description = getString(obj, "description"),
        .url = getString(obj, "web_url"),
        .default_branch = getString(obj, "default_branch"),
        .stars = getU64(obj, "star_count"),
        .forks = getU64(obj, "forks_count"),
        .open_issues = getU64(obj, "open_issues_count"),
        .visibility = getString(obj, "visibility"),
    };
}

// ── Issues ─────────────────────────────────────────────────────────────────

fn issueList(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8) ![]types.IssueInfo {
    const encoded = try encodeProjectPath(allocator, owner, repo);
    defer allocator.free(encoded);

    const path = try std.fmt.allocPrint(allocator, "/projects/{s}/issues?state=opened&per_page=30", .{encoded});
    defer allocator.free(path);

    var parsed = try apiGet(allocator, token, path);
    defer parsed.deinit();

    const arr = parsed.value.array.items;
    var list = try std.ArrayList(types.IssueInfo).initCapacity(allocator, arr.len);

    for (arr) |item| {
        const obj = item.object;

        // GitLab labels are an array of strings, not objects like GitHub
        var label_names = try std.ArrayList([]const u8).initCapacity(allocator, 4);
        if (obj.get("labels")) |labels_val| {
            for (labels_val.array.items) |lbl| {
                try label_names.append(allocator, lbl.string);
            }
        }

        try list.append(allocator, types.IssueInfo{
            .number = getU64(obj, "iid"),
            .title = getString(obj, "title"),
            .state = if (std.mem.eql(u8, getString(obj, "state"), "opened")) "open" else "closed",
            .author = if (obj.get("author")) |a| getString(a.object, "username") else "",
            .labels = try label_names.toOwnedSlice(allocator),
            .url = getString(obj, "web_url"),
            .created_at = getString(obj, "created_at"),
            .body = getString(obj, "description"),
        });
    }

    return list.toOwnedSlice(allocator);
}

fn issueView(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, number: u64) !types.IssueInfo {
    const encoded = try encodeProjectPath(allocator, owner, repo);
    defer allocator.free(encoded);

    const path = try std.fmt.allocPrint(allocator, "/projects/{s}/issues/{d}", .{ encoded, number });
    defer allocator.free(path);

    var parsed = try apiGet(allocator, token, path);
    defer parsed.deinit();

    const obj = parsed.value.object;

    var label_names = try std.ArrayList([]const u8).initCapacity(allocator, 4);
    if (obj.get("labels")) |labels_val| {
        for (labels_val.array.items) |lbl| {
            try label_names.append(allocator, lbl.string);
        }
    }

    return types.IssueInfo{
        .number = getU64(obj, "iid"),
        .title = getString(obj, "title"),
        .state = if (std.mem.eql(u8, getString(obj, "state"), "opened")) "open" else "closed",
        .author = if (obj.get("author")) |a| getString(a.object, "username") else "",
        .labels = try label_names.toOwnedSlice(allocator),
        .url = getString(obj, "web_url"),
        .created_at = getString(obj, "created_at"),
        .body = getString(obj, "description"),
    };
}

// ── Merge Requests ─────────────────────────────────────────────────────────

fn prList(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8) ![]types.PullRequestInfo {
    const encoded = try encodeProjectPath(allocator, owner, repo);
    defer allocator.free(encoded);

    const path = try std.fmt.allocPrint(allocator, "/projects/{s}/merge_requests?state=opened&per_page=30", .{encoded});
    defer allocator.free(path);

    var parsed = try apiGet(allocator, token, path);
    defer parsed.deinit();

    const arr = parsed.value.array.items;
    var list = try std.ArrayList(types.PullRequestInfo).initCapacity(allocator, arr.len);

    for (arr) |item| {
        const obj = item.object;
        try list.append(allocator, types.PullRequestInfo{
            .number = getU64(obj, "iid"),
            .title = getString(obj, "title"),
            .state = if (std.mem.eql(u8, getString(obj, "state"), "opened")) "open" else "closed",
            .author = if (obj.get("author")) |a| getString(a.object, "username") else "",
            .draft = getBool(obj, "draft"),
            .url = getString(obj, "web_url"),
            .created_at = getString(obj, "created_at"),
            .source_branch = getString(obj, "source_branch"),
            .target_branch = getString(obj, "target_branch"),
        });
    }

    return list.toOwnedSlice(allocator);
}

fn prView(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, number: u64) !types.PullRequestInfo {
    const encoded = try encodeProjectPath(allocator, owner, repo);
    defer allocator.free(encoded);

    const path = try std.fmt.allocPrint(allocator, "/projects/{s}/merge_requests/{d}", .{ encoded, number });
    defer allocator.free(path);

    var parsed = try apiGet(allocator, token, path);
    defer parsed.deinit();

    const obj = parsed.value.object;
    return types.PullRequestInfo{
        .number = getU64(obj, "iid"),
        .title = getString(obj, "title"),
        .state = if (std.mem.eql(u8, getString(obj, "state"), "opened")) "open" else "closed",
        .author = if (obj.get("author")) |a| getString(a.object, "username") else "",
        .draft = getBool(obj, "draft"),
        .url = getString(obj, "web_url"),
        .created_at = getString(obj, "created_at"),
        .source_branch = getString(obj, "source_branch"),
        .target_branch = getString(obj, "target_branch"),
    };
}

fn repoCreate(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, params: types.RepoCreateParams) !types.RepoInfo {
    _ = owner;
    const body = try std.fmt.allocPrint(allocator, "{{\"name\":\"{s}\",\"visibility\":\"{s}\"{s}}}", .{
        params.name,
        if (params.private) "private" else "public",
        if (params.description) |d| try std.fmt.allocPrint(allocator, ",\"description\":\"{s}\"", .{d}) else "",
    });
    defer allocator.free(body);

    var parsed = try apiPost(allocator, token, "/projects", body);
    defer parsed.deinit();

    const obj = parsed.value.object;
    return types.RepoInfo{
        .name = getString(obj, "name"),
        .full_name = getString(obj, "path_with_namespace"),
        .description = getString(obj, "description"),
        .url = getString(obj, "web_url"),
        .default_branch = getString(obj, "default_branch"),
        .stars = getU64(obj, "star_count"),
        .forks = getU64(obj, "forks_count"),
        .open_issues = getU64(obj, "open_issues_count"),
        .visibility = getString(obj, "visibility"),
    };
}

fn repoDelete(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8) !void {
    const encoded = try encodeProjectPath(allocator, owner, repo);
    defer allocator.free(encoded);

    const path = try std.fmt.allocPrint(allocator, "/projects/{s}", .{encoded});
    defer allocator.free(path);

    const url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ BASE_URL, path });
    defer allocator.free(url);

    const resp = try http.client.delete(allocator, url, token);
    defer allocator.free(resp.body);

    if (resp.status < 200 or resp.status >= 300) {
        std.log.err("GitLab API returned {d}: {s}", .{ resp.status, resp.body });
        return error.HttpError;
    }
}

fn repoArchive(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, archived: bool) !types.RepoInfo {
    const encoded = try encodeProjectPath(allocator, owner, repo);
    defer allocator.free(encoded);

    const path = if (archived)
        try std.fmt.allocPrint(allocator, "/projects/{s}/archive", .{encoded})
    else
        try std.fmt.allocPrint(allocator, "/projects/{s}/unarchive", .{encoded});
    defer allocator.free(path);

    var parsed = try apiPost(allocator, token, path, "");
    defer parsed.deinit();

    const obj = parsed.value.object;
    return types.RepoInfo{
        .name = getString(obj, "name"),
        .full_name = getString(obj, "path_with_namespace"),
        .description = getString(obj, "description"),
        .url = getString(obj, "web_url"),
        .default_branch = getString(obj, "default_branch"),
        .stars = getU64(obj, "star_count"),
        .forks = getU64(obj, "forks_count"),
        .open_issues = getU64(obj, "open_issues_count"),
        .visibility = getString(obj, "visibility"),
    };
}

pub const repo_vtable: types.RepoVtable = .{ .view = repoView, .create = repoCreate, .delete = repoDelete, .archive = repoArchive };

fn issueCreate(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, params: types.IssueCreateParams) !types.IssueInfo {
    const encoded = try encodeProjectPath(allocator, owner, repo);
    defer allocator.free(encoded);

    const path = try std.fmt.allocPrint(allocator, "/projects/{s}/issues", .{encoded});
    defer allocator.free(path);

    const body_str = params.body orelse "";
    const json_body = try std.fmt.allocPrint(allocator, "{{\"title\":\"{s}\",\"description\":\"{s}\"}}", .{ params.title, body_str });
    defer allocator.free(json_body);

    var parsed = try apiPost(allocator, token, path, json_body);
    defer parsed.deinit();

    const obj = parsed.value.object;
    var label_names = try std.ArrayList([]const u8).initCapacity(allocator, 4);
    if (obj.get("labels")) |labels_val| {
        for (labels_val.array.items) |lbl| {
            try label_names.append(allocator, lbl.string);
        }
    }

    return types.IssueInfo{
        .number = getU64(obj, "iid"),
        .title = getString(obj, "title"),
        .state = if (std.mem.eql(u8, getString(obj, "state"), "opened")) "open" else "closed",
        .author = if (obj.get("author")) |a| getString(a.object, "username") else "",
        .labels = try label_names.toOwnedSlice(allocator),
        .url = getString(obj, "web_url"),
        .created_at = getString(obj, "created_at"),
        .body = getString(obj, "description"),
    };
}

fn issueClose(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, number: u64) !types.IssueInfo {
    const encoded = try encodeProjectPath(allocator, owner, repo);
    defer allocator.free(encoded);

    const path = try std.fmt.allocPrint(allocator, "/projects/{s}/issues/{d}", .{ encoded, number });
    defer allocator.free(path);

    var parsed = try apiPut(allocator, token, path, "{\"state_event\":\"close\"}");
    defer parsed.deinit();

    const obj = parsed.value.object;
    var label_names = try std.ArrayList([]const u8).initCapacity(allocator, 4);
    if (obj.get("labels")) |labels_val| {
        for (labels_val.array.items) |lbl| {
            try label_names.append(allocator, lbl.string);
        }
    }

    return types.IssueInfo{
        .number = getU64(obj, "iid"),
        .title = getString(obj, "title"),
        .state = if (std.mem.eql(u8, getString(obj, "state"), "opened")) "open" else "closed",
        .author = if (obj.get("author")) |a| getString(a.object, "username") else "",
        .labels = try label_names.toOwnedSlice(allocator),
        .url = getString(obj, "web_url"),
        .created_at = getString(obj, "created_at"),
        .body = getString(obj, "description"),
    };
}

pub const issue_vtable: types.IssueVtable = .{ .list = issueList, .view = issueView, .create = issueCreate, .close = issueClose };

fn prCreate(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, params: types.PRCreateParams) !types.PullRequestInfo {
    const encoded = try encodeProjectPath(allocator, owner, repo);
    defer allocator.free(encoded);

    const path = try std.fmt.allocPrint(allocator, "/projects/{s}/merge_requests", .{encoded});
    defer allocator.free(path);

    const body_str = params.body orelse "";
    const json_body = try std.fmt.allocPrint(allocator, "{{\"title\":\"{s}\",\"source_branch\":\"{s}\",\"target_branch\":\"{s}\",\"description\":\"{s}\"}}", .{ params.title, params.head, params.base, body_str });
    defer allocator.free(json_body);

    var parsed = try apiPost(allocator, token, path, json_body);
    defer parsed.deinit();

    const obj = parsed.value.object;
    return types.PullRequestInfo{
        .number = getU64(obj, "iid"),
        .title = getString(obj, "title"),
        .state = if (std.mem.eql(u8, getString(obj, "state"), "opened")) "open" else "closed",
        .author = if (obj.get("author")) |a| getString(a.object, "username") else "",
        .draft = getBool(obj, "draft"),
        .url = getString(obj, "web_url"),
        .created_at = getString(obj, "created_at"),
        .source_branch = getString(obj, "source_branch"),
        .target_branch = getString(obj, "target_branch"),
    };
}

fn prMerge(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, number: u64) !void {
    const encoded = try encodeProjectPath(allocator, owner, repo);
    defer allocator.free(encoded);

    const path = try std.fmt.allocPrint(allocator, "/projects/{s}/merge_requests/{d}/merge", .{ encoded, number });
    defer allocator.free(path);

    const url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ BASE_URL, path });
    defer allocator.free(url);

    const resp = try http.client.put(allocator, url, token, "{}");
    defer allocator.free(resp.body);

    if (resp.status < 200 or resp.status >= 300) {
        std.log.err("GitLab API returned {d}: {s}", .{ resp.status, resp.body });
        return error.HttpError;
    }
}

pub const pr_vtable: types.PRVtable = .{ .list = prList, .view = prView, .create = prCreate, .merge = prMerge };

fn labelSetAll(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, params: types.LabelParams) !void {
    const encoded = try encodeProjectPath(allocator, owner, repo);
    defer allocator.free(encoded);

    // 1. List existing labels
    const list_path = try std.fmt.allocPrint(allocator, "/projects/{s}/labels?per_page=100", .{encoded});
    defer allocator.free(list_path);

    var list_parsed = try apiGet(allocator, token, list_path);
    defer list_parsed.deinit();

    // 2. Delete existing labels
    for (list_parsed.value.array.items) |item| {
        const raw_name = getString(item.object, "name");
        const del_path = try std.fmt.allocPrint(allocator, "/projects/{s}/labels/{s}", .{ encoded, raw_name });
        defer allocator.free(del_path);

        const del_url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ BASE_URL, del_path });
        defer allocator.free(del_url);

        const resp = try http.client.delete(allocator, del_url, token);
        defer allocator.free(resp.body);
        if (resp.status < 200 or resp.status >= 300) {
            std.log.err("GitLab API DELETE returned {d}: {s}", .{ resp.status, resp.body });
            return error.HttpError;
        }
    }

    // 3. Create all new labels
    for (params.labels) |ldef| {
        const create_path = try std.fmt.allocPrint(allocator, "/projects/{s}/labels", .{encoded});
        defer allocator.free(create_path);

        const color = ldef.color orelse "d73a4a";
        const body = try std.fmt.allocPrint(allocator, "{{\"name\":\"{s}\",\"color\":\"#{s}\"}}", .{ ldef.name, color });
        defer allocator.free(body);

        var parsed = try apiPost(allocator, token, create_path, body);
        parsed.deinit();
    }
}

pub const label_vtable: types.LabelVtable = .{ .set_all = labelSetAll };

test {
    _ = repo_vtable;
    _ = issue_vtable;
    _ = pr_vtable;
    _ = label_vtable;
}
