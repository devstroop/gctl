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

const GITHUB_ACCEPT = "application/vnd.github+json";

fn apiGet(allocator: std.mem.Allocator, token: []const u8, path: []const u8) !std.json.Parsed(std.json.Value) {
    const url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ BASE_URL, path });
    defer allocator.free(url);

    const resp = try http.client.getAccept(allocator, url, token, GITHUB_ACCEPT);
    defer allocator.free(resp.body);

    if (resp.status < 200 or resp.status >= 300) {
        std.log.err("GitHub API returned {d}: {s}", .{ resp.status, resp.body });
        return error.HttpError;
    }

    return std.json.parseFromSlice(std.json.Value, allocator, resp.body, .{ .allocate = .alloc_always });
}

fn apiPost(allocator: std.mem.Allocator, token: []const u8, path: []const u8, body: []const u8) !std.json.Parsed(std.json.Value) {
    const url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ BASE_URL, path });
    defer allocator.free(url);

    const resp = try http.client.postAccept(allocator, url, token, body, GITHUB_ACCEPT);
    defer allocator.free(resp.body);

    if (resp.status < 200 or resp.status >= 300) {
        std.log.err("GitHub API returned {d}: {s}", .{ resp.status, resp.body });
        return error.HttpError;
    }

    return std.json.parseFromSlice(std.json.Value, allocator, resp.body, .{ .allocate = .alloc_always });
}

fn apiPatch(allocator: std.mem.Allocator, token: []const u8, path: []const u8, body: []const u8) !std.json.Parsed(std.json.Value) {
    const url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ BASE_URL, path });
    defer allocator.free(url);

    const resp = try http.client.patchAccept(allocator, url, token, body, GITHUB_ACCEPT);
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

fn repoCreate(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, params: types.RepoCreateParams) !types.RepoInfo {
    // For org repos: POST /orgs/{owner}/repos; for user repos: POST /user/repos
    const path = if (std.mem.eql(u8, owner, "user") or owner.len == 0)
        try std.fmt.allocPrint(allocator, "/user/repos", .{})
    else
        try std.fmt.allocPrint(allocator, "/orgs/{s}/repos", .{owner});
    defer allocator.free(path);

    const body = try std.fmt.allocPrint(allocator, "{{\"name\":\"{s}\",\"description\":{s},\"private\":{s}}}", .{
        params.name,
        if (params.description) |d| try std.fmt.allocPrint(allocator, "\"{s}\"", .{d}) else "null",
        if (params.private) "true" else "false",
    });
    defer allocator.free(body);

    var parsed = try apiPost(allocator, token, path, body);
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

fn repoDelete(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8) !void {
    const path = try std.fmt.allocPrint(allocator, "/repos/{s}/{s}", .{ owner, repo });
    defer allocator.free(path);

    const url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ BASE_URL, path });
    defer allocator.free(url);

    const resp = try http.client.deleteAccept(allocator, url, token, GITHUB_ACCEPT);
    defer allocator.free(resp.body);

    if (resp.status < 200 or resp.status >= 300) {
        std.log.err("GitHub API returned {d}: {s}", .{ resp.status, resp.body });
        return error.HttpError;
    }
}

fn repoArchive(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, archived: bool) !types.RepoInfo {
    const path = try std.fmt.allocPrint(allocator, "/repos/{s}/{s}", .{ owner, repo });
    defer allocator.free(path);

    const body = try std.fmt.allocPrint(allocator, "{{\"archived\":{s}}}", .{if (archived) "true" else "false"});
    defer allocator.free(body);

    var parsed = try apiPatch(allocator, token, path, body);
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

pub const repo_vtable: types.RepoVtable = .{ .view = repoView, .create = repoCreate, .delete = repoDelete, .archive = repoArchive };

// ── Labels ──────────────────────────────────────────────────────────────────

fn encodeLabel(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    var buf = try std.ArrayList(u8).initCapacity(allocator, name.len * 3);
    for (name) |c| {
        switch (c) {
            ' ', '#', '%', '/', '?', '&', '=', ':', '@', '!' => {
                try buf.append(allocator, '%');
                try buf.append(allocator, std.fmt.digitToChar(c >> 4, .upper));
                try buf.append(allocator, std.fmt.digitToChar(c & 0xF, .upper));
            },
            else => try buf.append(allocator, c),
        }
    }
    return buf.toOwnedSlice(allocator);
}

fn labelSetAll(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, params: types.LabelParams) !void {
    // 1. List existing labels
    const list_path = try std.fmt.allocPrint(allocator, "/repos/{s}/{s}/labels?per_page=100", .{ owner, repo });
    defer allocator.free(list_path);

    var list_parsed = try apiGet(allocator, token, list_path);
    defer list_parsed.deinit();

    // 2. Delete existing labels
    for (list_parsed.value.array.items) |item| {
        const raw_name = getString(item.object, "name");
        const encoded_name = try encodeLabel(allocator, raw_name);
        defer allocator.free(encoded_name);

        const del_path = try std.fmt.allocPrint(allocator, "/repos/{s}/{s}/labels/{s}", .{ owner, repo, encoded_name });
        defer allocator.free(del_path);

        const del_url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ BASE_URL, del_path });
        defer allocator.free(del_url);

        const resp = try http.client.deleteAccept(allocator, del_url, token, GITHUB_ACCEPT);
        defer allocator.free(resp.body);
        if (resp.status < 200 or resp.status >= 300) {
            std.log.err("GitHub API DELETE returned {d}: {s}", .{ resp.status, resp.body });
            return error.HttpError;
        }
    }

    // 3. Create all new labels
    for (params.labels) |ldef| {
        const create_path = try std.fmt.allocPrint(allocator, "/repos/{s}/{s}/labels", .{ owner, repo });
        defer allocator.free(create_path);

        const color = ldef.color orelse "d73a4a";
        const body = try std.fmt.allocPrint(allocator, "{{\"name\":\"{s}\",\"color\":\"{s}\"}}", .{ ldef.name, color });
        defer allocator.free(body);

        var parsed = try apiPost(allocator, token, create_path, body);
        parsed.deinit();
    }
}

pub const label_vtable: types.LabelVtable = .{ .set_all = labelSetAll };

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

fn issueCreate(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, params: types.IssueCreateParams) !types.IssueInfo {
    const path = try std.fmt.allocPrint(allocator, "/repos/{s}/{s}/issues", .{ owner, repo });
    defer allocator.free(path);

    const body_str = params.body orelse "";
    const json_body = try std.fmt.allocPrint(allocator, "{{\"title\":\"{s}\",\"body\":\"{s}\"}}", .{ params.title, body_str });
    defer allocator.free(json_body);

    var parsed = try apiPost(allocator, token, path, json_body);
    defer parsed.deinit();

    const obj = parsed.value.object;
    var label_names = try std.ArrayList([]const u8).initCapacity(allocator, 4);
    if (obj.get("labels")) |labels_val| {
        for (labels_val.array.items) |lbl| {
            try label_names.append(allocator, getString(lbl.object, "name"));
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

fn issueClose(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, number: u64) !types.IssueInfo {
    const path = try std.fmt.allocPrint(allocator, "/repos/{s}/{s}/issues/{d}", .{ owner, repo, number });
    defer allocator.free(path);

    const json_body = "{\"state\":\"closed\"}";

    var parsed = try apiPatch(allocator, token, path, json_body);
    defer parsed.deinit();

    const obj = parsed.value.object;
    var label_names = try std.ArrayList([]const u8).initCapacity(allocator, 4);
    if (obj.get("labels")) |labels_val| {
        for (labels_val.array.items) |lbl| {
            try label_names.append(allocator, getString(lbl.object, "name"));
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

pub const issue_vtable: types.IssueVtable = .{ .list = issueList, .view = issueView, .create = issueCreate, .close = issueClose };

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

fn prCreate(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, params: types.PRCreateParams) !types.PullRequestInfo {
    const path = try std.fmt.allocPrint(allocator, "/repos/{s}/{s}/pulls", .{ owner, repo });
    defer allocator.free(path);

    const body_str = params.body orelse "";
    const json_body = try std.fmt.allocPrint(allocator, "{{\"title\":\"{s}\",\"head\":\"{s}\",\"base\":\"{s}\",\"body\":\"{s}\"}}", .{ params.title, params.head, params.base, body_str });
    defer allocator.free(json_body);

    var parsed = try apiPost(allocator, token, path, json_body);
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

fn prMerge(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, number: u64) !void {
    const path = try std.fmt.allocPrint(allocator, "/repos/{s}/{s}/pulls/{d}/merge", .{ owner, repo, number });
    defer allocator.free(path);

    const url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ BASE_URL, path });
    defer allocator.free(url);

    const resp = try http.client.putAccept(allocator, url, token, "{}", GITHUB_ACCEPT);
    defer allocator.free(resp.body);

    if (resp.status < 200 or resp.status >= 300) {
        std.log.err("GitHub API PUT returned {d}: {s}", .{ resp.status, resp.body });
        return error.HttpError;
    }
}

pub const pr_vtable: types.PRVtable = .{ .list = prList, .view = prView, .create = prCreate, .merge = prMerge };

// ── Releases ────────────────────────────────────────────────────────────────

fn releaseList(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8) ![]types.ReleaseInfo {
    const path = try std.fmt.allocPrint(allocator, "/repos/{s}/{s}/releases?per_page=30", .{ owner, repo });
    defer allocator.free(path);

    var parsed = try apiGet(allocator, token, path);
    defer parsed.deinit();

    const arr = parsed.value.array.items;
    var list = try std.ArrayList(types.ReleaseInfo).initCapacity(allocator, arr.len);

    for (arr) |item| {
        const obj = item.object;
        try list.append(allocator, types.ReleaseInfo{
            .tag_name = getString(obj, "tag_name"),
            .name = getString(obj, "name"),
            .body = getString(obj, "body"),
            .draft = getBool(obj, "draft"),
            .prerelease = getBool(obj, "prerelease"),
            .url = getString(obj, "html_url"),
            .created_at = getString(obj, "published_at"),
        });
    }

    return list.toOwnedSlice(allocator);
}

fn releaseView(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, tag: []const u8) !types.ReleaseInfo {
    const encoded = try encodeLabel(allocator, tag);
    defer allocator.free(encoded);

    const path = try std.fmt.allocPrint(allocator, "/repos/{s}/{s}/releases/tags/{s}", .{ owner, repo, encoded });
    defer allocator.free(path);

    var parsed = try apiGet(allocator, token, path);
    defer parsed.deinit();

    const obj = parsed.value.object;
    return types.ReleaseInfo{
        .tag_name = getString(obj, "tag_name"),
        .name = getString(obj, "name"),
        .body = getString(obj, "body"),
        .draft = getBool(obj, "draft"),
        .prerelease = getBool(obj, "prerelease"),
        .url = getString(obj, "html_url"),
        .created_at = getString(obj, "published_at"),
    };
}

fn releaseCreate(allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, params: types.ReleaseCreateParams) !types.ReleaseInfo {
    const path = try std.fmt.allocPrint(allocator, "/repos/{s}/{s}/releases", .{ owner, repo });
    defer allocator.free(path);

    const name_str = params.name orelse "";
    const body_str = params.body orelse "";
    const json_body = try std.fmt.allocPrint(allocator, "{{\"tag_name\":\"{s}\",\"name\":\"{s}\",\"body\":\"{s}\",\"draft\":{s},\"prerelease\":{s}}}", .{
        params.tag_name,
        name_str,
        body_str,
        if (params.draft) "true" else "false",
        if (params.prerelease) "true" else "false",
    });
    defer allocator.free(json_body);

    var parsed = try apiPost(allocator, token, path, json_body);
    defer parsed.deinit();

    const obj = parsed.value.object;
    return types.ReleaseInfo{
        .tag_name = getString(obj, "tag_name"),
        .name = getString(obj, "name"),
        .body = getString(obj, "body"),
        .draft = getBool(obj, "draft"),
        .prerelease = getBool(obj, "prerelease"),
        .url = getString(obj, "html_url"),
        .created_at = getString(obj, "published_at"),
    };
}

pub const release_vtable: types.ReleaseVtable = .{ .list = releaseList, .view = releaseView, .create = releaseCreate };

test {
    _ = repo_vtable;
    _ = issue_vtable;
    _ = pr_vtable;
    _ = label_vtable;
    _ = release_vtable;
}
