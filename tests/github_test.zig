const std = @import("std");

fn getString(obj: std.json.ObjectMap, key: []const u8) []const u8 {
    return if (obj.get(key)) |v| v.string else "";
}

fn getU64(obj: std.json.ObjectMap, key: []const u8) u64 {
    return if (obj.get(key)) |v| @intCast(v.integer) else 0;
}

fn getBool(obj: std.json.ObjectMap, key: []const u8) bool {
    return if (obj.get(key)) |v| v.bool else false;
}

test "github: parse repo response" {
    const json =
        \\{
        \\  "name": "gctl",
        \\  "full_name": "user/gctl",
        \\  "description": "One CLI for every Git forge",
        \\  "html_url": "https://github.com/user/gctl",
        \\  "default_branch": "main",
        \\  "stargazers_count": 42,
        \\  "forks_count": 7,
        \\  "open_issues_count": 3,
        \\  "visibility": "public"
        \\}
    ;

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    const obj = parsed.value.object;

    try std.testing.expectEqualStrings("gctl", getString(obj, "name"));
    try std.testing.expectEqualStrings("user/gctl", getString(obj, "full_name"));
    try std.testing.expectEqualStrings("One CLI for every Git forge", getString(obj, "description"));
    try std.testing.expectEqualStrings("https://github.com/user/gctl", getString(obj, "html_url"));
    try std.testing.expectEqualStrings("main", getString(obj, "default_branch"));
    try std.testing.expectEqual(@as(u64, 42), getU64(obj, "stargazers_count"));
    try std.testing.expectEqual(@as(u64, 7), getU64(obj, "forks_count"));
    try std.testing.expectEqual(@as(u64, 3), getU64(obj, "open_issues_count"));
    try std.testing.expectEqualStrings("public", getString(obj, "visibility"));
}

test "github: parse repo response with optional fields" {
    const json =
        \\{
        \\  "name": "private-repo",
        \\  "full_name": "org/private-repo",
        \\  "description": "",
        \\  "html_url": "https://github.com/org/private-repo",
        \\  "default_branch": "master",
        \\  "stargazers_count": 0,
        \\  "forks_count": 0,
        \\  "open_issues_count": 0,
        \\  "visibility": "private"
        \\}
    ;

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{ .allocate = .alloc_always });
    defer parsed.deinit();
    const obj = parsed.value.object;

    try std.testing.expectEqualStrings("private-repo", getString(obj, "name"));
    try std.testing.expectEqualStrings("master", getString(obj, "default_branch"));
    try std.testing.expectEqual(@as(u64, 0), getU64(obj, "stargazers_count"));
    try std.testing.expectEqualStrings("private", getString(obj, "visibility"));
}

test "github: parse issue list response" {
    const json =
        \\[
        \\  {
        \\    "number": 1,
        \\    "title": "Fix login bug",
        \\    "state": "open",
        \\    "user": {"login": "alice"},
        \\    "labels": [{"name": "bug"}, {"name": "high-priority"}],
        \\    "html_url": "https://github.com/user/gctl/issues/1",
        \\    "created_at": "2026-01-15T10:00:00Z",
        \\    "body": "Users cannot log in with SSO"
        \\  },
        \\  {
        \\    "number": 2,
        \\    "title": "Add dark mode",
        \\    "state": "open",
        \\    "user": {"login": "bob"},
        \\    "labels": [{"name": "enhancement"}],
        \\    "html_url": "https://github.com/user/gctl/issues/2",
        \\    "created_at": "2026-02-01T14:30:00Z",
        \\    "body": "Would be nice to have dark mode support"
        \\  }
        \\]
    ;

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    const arr = parsed.value.array.items;
    try std.testing.expectEqual(@as(usize, 2), arr.len);

    // First issue
    {
        const obj = arr[0].object;
        try std.testing.expectEqual(@as(u64, 1), getU64(obj, "number"));
        try std.testing.expectEqualStrings("Fix login bug", getString(obj, "title"));
        try std.testing.expectEqualStrings("open", getString(obj, "state"));
        try std.testing.expectEqualStrings("alice", getString(obj.get("user").?.object, "login"));

        const labels = obj.get("labels").?.array.items;
        try std.testing.expectEqual(@as(usize, 2), labels.len);
        try std.testing.expectEqualStrings("bug", labels[0].object.get("name").?.string);
        try std.testing.expectEqualStrings("high-priority", labels[1].object.get("name").?.string);

        try std.testing.expectEqualStrings("https://github.com/user/gctl/issues/1", getString(obj, "html_url"));
    }

    // Second issue
    {
        const obj = arr[1].object;
        try std.testing.expectEqual(@as(u64, 2), getU64(obj, "number"));
        try std.testing.expectEqualStrings("bob", getString(obj.get("user").?.object, "login"));
        try std.testing.expectEqualStrings("https://github.com/user/gctl/issues/2", getString(obj, "html_url"));
    }
}

test "github: parse issue with pull_request field skipped" {
    // GitHub's /repos/{o}/{r}/issues endpoint includes PRs.
    // Items with a "pull_request" field must be filtered out.
    const json =
        \\[
        \\  {
        \\    "number": 3,
        \\    "title": "Real issue",
        \\    "state": "open",
        \\    "user": {"login": "charlie"},
        \\    "labels": [],
        \\    "html_url": "https://github.com/user/gctl/issues/3",
        \\    "created_at": "2026-03-01T09:00:00Z",
        \\    "body": "This is a real issue"
        \\  },
        \\  {
        \\    "number": 4,
        \\    "title": "PR that appears in issues endpoint",
        \\    "state": "open",
        \\    "user": {"login": "dave"},
        \\    "labels": [],
        \\    "html_url": "https://github.com/user/gctl/pull/4",
        \\    "created_at": "2026-03-02T09:00:00Z",
        \\    "body": "",
        \\    "pull_request": {}
        \\  }
        \\]
    ;

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    // Verify the PR item has pull_request field that should trigger filtering
    const arr = parsed.value.array.items;
    try std.testing.expectEqual(@as(usize, 2), arr.len);

    // First item is a real issue
    try std.testing.expect(arr[0].object.get("pull_request") == null);

    // Second item has pull_request field
    try std.testing.expect(arr[1].object.get("pull_request") != null);
}

test "github: parse PR list response" {
    const json =
        \\[
        \\  {
        \\    "number": 10,
        \\    "title": "Add new feature",
        \\    "state": "open",
        \\    "user": {"login": "alice"},
        \\    "draft": false,
        \\    "html_url": "https://github.com/user/gctl/pull/10",
        \\    "created_at": "2026-04-01T08:00:00Z",
        \\    "head": {"ref": "feature/new-stuff"},
        \\    "base": {"ref": "main"}
        \\  },
        \\  {
        \\    "number": 11,
        \\    "title": "WIP: refactoring",
        \\    "state": "open",
        \\    "user": {"login": "bob"},
        \\    "draft": true,
        \\    "html_url": "https://github.com/user/gctl/pull/11",
        \\    "created_at": "2026-04-05T12:00:00Z",
        \\    "head": {"ref": "refactor/auth"},
        \\    "base": {"ref": "develop"}
        \\  }
        \\]
    ;

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    const arr = parsed.value.array.items;
    try std.testing.expectEqual(@as(usize, 2), arr.len);

    // First PR
    {
        const obj = arr[0].object;
        try std.testing.expectEqual(@as(u64, 10), getU64(obj, "number"));
        try std.testing.expectEqualStrings("Add new feature", getString(obj, "title"));
        try std.testing.expectEqualStrings("open", getString(obj, "state"));
        try std.testing.expectEqualStrings("alice", getString(obj.get("user").?.object, "login"));
        try std.testing.expectEqual(false, getBool(obj, "draft"));
        try std.testing.expectEqualStrings("feature/new-stuff", getString(obj.get("head").?.object, "ref"));
        try std.testing.expectEqualStrings("main", getString(obj.get("base").?.object, "ref"));
    }

    // Second PR (draft)
    {
        const obj = arr[1].object;
        try std.testing.expectEqual(@as(u64, 11), getU64(obj, "number"));
        try std.testing.expectEqual(true, getBool(obj, "draft"));
        try std.testing.expectEqualStrings("refactor/auth", getString(obj.get("head").?.object, "ref"));
        try std.testing.expectEqualStrings("develop", getString(obj.get("base").?.object, "ref"));
    }
}

test "github: parse empty issue list" {
    const json = "[]";
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{ .allocate = .alloc_always });
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 0), parsed.value.array.items.len);
}

test "github: parse empty PR list" {
    const json = "[]";
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{ .allocate = .alloc_always });
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 0), parsed.value.array.items.len);
}

test "github: parse single issue view response" {
    const json =
        \\{
        \\  "number": 5,
        \\  "title": "Detailed bug report",
        \\  "state": "closed",
        \\  "user": {"login": "eve"},
        \\  "labels": [{"name": "bug"}, {"name": "fixed"}],
        \\  "html_url": "https://github.com/user/gctl/issues/5",
        \\  "created_at": "2026-05-10T16:00:00Z",
        \\  "body": "This bug was found in production. Steps to reproduce..."
        \\}
    ;

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    const obj = parsed.value.object;
    try std.testing.expectEqualStrings("Detailed bug report", getString(obj, "title"));
    try std.testing.expectEqualStrings("closed", getString(obj, "state"));
    try std.testing.expectEqualStrings("eve", getString(obj.get("user").?.object, "login"));

    const labels = obj.get("labels").?.array.items;
    try std.testing.expectEqual(@as(usize, 2), labels.len);
    try std.testing.expectEqualStrings("bug", labels[0].object.get("name").?.string);
    try std.testing.expectEqualStrings("fixed", labels[1].object.get("name").?.string);

    try std.testing.expectEqualStrings("This bug was found in production. Steps to reproduce...", getString(obj, "body"));
}
