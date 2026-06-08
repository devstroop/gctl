const std = @import("std");

fn getString(obj: std.json.ObjectMap, key: []const u8) []const u8 {
    return if (obj.get(key)) |v| v.string else "";
}

fn getU64(obj: std.json.ObjectMap, key: []const u8) u64 {
    return if (obj.get(key)) |v| @intCast(v.integer) else 0;
}

test "gitlab: parse repo response" {
    const json =
        \\{
        \\  "id": 1,
        \\  "name": "gctl",
        \\  "name_with_namespace": "user/gctl",
        \\  "description": "One CLI for every Git forge",
        \\  "web_url": "https://gitlab.com/user/gctl",
        \\  "default_branch": "main",
        \\  "star_count": 42,
        \\  "forks_count": 7,
        \\  "open_issues_count": 3,
        \\  "visibility": "public"
        \\}
    ;

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    const obj = parsed.value.object;

    try std.testing.expectEqualStrings("gctl", getString(obj, "name"));
    try std.testing.expectEqualStrings("user/gctl", getString(obj, "name_with_namespace"));
    try std.testing.expectEqualStrings("One CLI for every Git forge", getString(obj, "description"));
    try std.testing.expectEqualStrings("https://gitlab.com/user/gctl", getString(obj, "web_url"));
    try std.testing.expectEqualStrings("main", getString(obj, "default_branch"));
    try std.testing.expectEqual(@as(u64, 42), getU64(obj, "star_count"));
    try std.testing.expectEqual(@as(u64, 7), getU64(obj, "forks_count"));
    try std.testing.expectEqual(@as(u64, 3), getU64(obj, "open_issues_count"));
    try std.testing.expectEqualStrings("public", getString(obj, "visibility"));
}

test "gitlab: parse issue list response" {
    const json =
        \\[
        \\  {
        \\    "iid": 1,
        \\    "title": "Fix login bug",
        \\    "state": "opened",
        \\    "author": {"username": "alice"},
        \\    "labels": ["bug", "high-priority"],
        \\    "web_url": "https://gitlab.com/user/gctl/-/issues/1",
        \\    "created_at": "2026-01-15T10:00:00Z",
        \\    "description": "Users cannot log in with SSO"
        \\  },
        \\  {
        \\    "iid": 2,
        \\    "title": "Add dark mode",
        \\    "state": "closed",
        \\    "author": {"username": "bob"},
        \\    "labels": ["enhancement"],
        \\    "web_url": "https://gitlab.com/user/gctl/-/issues/2",
        \\    "created_at": "2026-02-01T14:30:00Z",
        \\    "description": "Implemented dark mode"
        \\  }
        \\]
    ;

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    const arr = parsed.value.array.items;
    try std.testing.expectEqual(@as(usize, 2), arr.len);

    // First issue (opened)
    {
        const obj = arr[0].object;
        try std.testing.expectEqual(@as(u64, 1), getU64(obj, "iid"));
        try std.testing.expectEqualStrings("Fix login bug", getString(obj, "title"));
        try std.testing.expectEqualStrings("opened", getString(obj, "state"));
        try std.testing.expectEqualStrings("alice", getString(obj.get("author").?.object, "username"));

        const labels = obj.get("labels").?.array.items;
        try std.testing.expectEqual(@as(usize, 2), labels.len);
        try std.testing.expectEqualStrings("bug", labels[0].string);
        try std.testing.expectEqualStrings("high-priority", labels[1].string);

        try std.testing.expectEqualStrings("https://gitlab.com/user/gctl/-/issues/1", getString(obj, "web_url"));
        try std.testing.expectEqualStrings("Users cannot log in with SSO", getString(obj, "description"));
    }

    // Second issue (closed)
    {
        const obj = arr[1].object;
        try std.testing.expectEqual(@as(u64, 2), getU64(obj, "iid"));
        try std.testing.expectEqualStrings("closed", getString(obj, "state"));
        try std.testing.expectEqualStrings("bob", getString(obj.get("author").?.object, "username"));
        try std.testing.expectEqualStrings("enhancement", obj.get("labels").?.array.items[0].string);
    }
}

test "gitlab: parse issue with no labels" {
    const json =
        \\[
        \\  {
        \\    "iid": 3,
        \\    "title": "Untriaged issue",
        \\    "state": "opened",
        \\    "author": {"username": "charlie"},
        \\    "labels": [],
        \\    "web_url": "https://gitlab.com/user/gctl/-/issues/3",
        \\    "created_at": "2026-03-01T09:00:00Z",
        \\    "description": "No labels yet"
        \\  }
        \\]
    ;

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    const labels = parsed.value.array.items[0].object.get("labels").?.array;
    try std.testing.expectEqual(@as(usize, 0), labels.items.len);
}

test "gitlab: parse single issue view" {
    const json =
        \\{
        \\  "iid": 5,
        \\  "title": "Detailed bug report",
        \\  "state": "closed",
        \\  "author": {"username": "eve"},
        \\  "labels": ["bug", "regression"],
        \\  "web_url": "https://gitlab.com/user/gctl/-/issues/5",
        \\  "created_at": "2026-05-10T16:00:00Z",
        \\  "description": "Found in production. Steps to reproduce..."
        \\}
    ;

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    const obj = parsed.value.object;
    try std.testing.expectEqualStrings("Detailed bug report", getString(obj, "title"));
    try std.testing.expectEqualStrings("closed", getString(obj, "state"));
    try std.testing.expectEqualStrings("eve", getString(obj.get("author").?.object, "username"));
    try std.testing.expectEqualStrings("Found in production. Steps to reproduce...", getString(obj, "description"));
}

test "gitlab: parse repo response with internal visibility" {
    const json =
        \\{
        \\  "name": "internal-tool",
        \\  "name_with_namespace": "org/internal-tool",
        \\  "description": "",
        \\  "web_url": "https://gitlab.com/org/internal-tool",
        \\  "default_branch": "master",
        \\  "star_count": 0,
        \\  "forks_count": 0,
        \\  "open_issues_count": 5,
        \\  "visibility": "internal"
        \\}
    ;

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    const obj = parsed.value.object;

    try std.testing.expectEqualStrings("internal-tool", getString(obj, "name"));
    try std.testing.expectEqualStrings("master", getString(obj, "default_branch"));
    try std.testing.expectEqual(@as(u64, 0), getU64(obj, "star_count"));
    try std.testing.expectEqual(@as(u64, 5), getU64(obj, "open_issues_count"));
    try std.testing.expectEqualStrings("internal", getString(obj, "visibility"));
}
