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

test "gitea: parse repo response" {
    const json =
        \\{
        \\  "name": "my-project",
        \\  "full_name": "user/my-project",
        \\  "description": "A Gitea project",
        \\  "html_url": "https://gitea.com/user/my-project",
        \\  "default_branch": "main",
        \\  "stars_count": 10,
        \\  "forks_count": 3,
        \\  "open_issues_count": 1,
        \\  "private": false
        \\}
    ;

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    const obj = parsed.value.object;

    try std.testing.expectEqualStrings("my-project", getString(obj, "name"));
    try std.testing.expectEqualStrings("user/my-project", getString(obj, "full_name"));
    try std.testing.expectEqualStrings("A Gitea project", getString(obj, "description"));
    try std.testing.expectEqualStrings("https://gitea.com/user/my-project", getString(obj, "html_url"));
    try std.testing.expectEqualStrings("main", getString(obj, "default_branch"));
    try std.testing.expectEqual(@as(u64, 10), getU64(obj, "stars_count"));
    try std.testing.expectEqual(@as(u64, 3), getU64(obj, "forks_count"));
    try std.testing.expectEqual(@as(u64, 1), getU64(obj, "open_issues_count"));
    try std.testing.expectEqual(false, getBool(obj, "private"));
}

test "gitea: parse private repo" {
    const json =
        \\{
        \\  "name": "secret-project",
        \\  "full_name": "org/secret-project",
        \\  "description": "",
        \\  "html_url": "https://gitea.com/org/secret-project",
        \\  "default_branch": "develop",
        \\  "stars_count": 0,
        \\  "forks_count": 0,
        \\  "open_issues_count": 0,
        \\  "private": true
        \\}
    ;

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    const obj = parsed.value.object;

    try std.testing.expectEqualStrings("secret-project", getString(obj, "name"));
    try std.testing.expectEqualStrings("develop", getString(obj, "default_branch"));
    try std.testing.expectEqual(true, getBool(obj, "private"));
}

test "gitea: parse issue list" {
    const json =
        \\[
        \\  {
        \\    "number": 1,
        \\    "title": "Fix the widget",
        \\    "state": "open",
        \\    "user": {"login": "alice"},
        \\    "labels": [
        \\      {"name": "bug"},
        \\      {"name": "urgent"}
        \\    ],
        \\    "html_url": "https://gitea.com/user/my-project/issues/1",
        \\    "created_at": "2026-01-15T10:00:00Z",
        \\    "body": "The widget is broken"
        \\  },
        \\  {
        \\    "number": 2,
        \\    "title": "Add tests",
        \\    "state": "open",
        \\    "user": {"login": "bob"},
        \\    "labels": [{"name": "enhancement"}],
        \\    "html_url": "https://gitea.com/user/my-project/issues/2",
        \\    "created_at": "2026-01-16T14:30:00Z",
        \\    "body": "We need more tests"
        \\  }
        \\]
    ;

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    const arr = parsed.value.array.items;
    try std.testing.expectEqual(@as(usize, 2), arr.len);

    // First issue
    const first = arr[0].object;
    try std.testing.expectEqual(@as(u64, 1), getU64(first, "number"));
    try std.testing.expectEqualStrings("Fix the widget", getString(first, "title"));
    try std.testing.expectEqualStrings("open", getString(first, "state"));
    try std.testing.expectEqualStrings("alice", getString(first.get("user").?.object, "login"));
    try std.testing.expectEqual(@as(usize, 2), first.get("labels").?.array.items.len);

    // Second issue
    const second = arr[1].object;
    try std.testing.expectEqual(@as(u64, 2), getU64(second, "number"));
    try std.testing.expectEqualStrings("Add tests", getString(second, "title"));
    try std.testing.expectEqual(@as(usize, 1), second.get("labels").?.array.items.len);
}

test "gitea: parse PR list" {
    const json =
        \\[
        \\  {
        \\    "number": 10,
        \\    "title": "New feature",
        \\    "state": "open",
        \\    "user": {"login": "charlie"},
        \\    "draft": false,
        \\    "html_url": "https://gitea.com/user/my-project/pulls/10",
        \\    "created_at": "2026-02-01T09:00:00Z",
        \\    "head": {"label": "charlie:feature-branch"},
        \\    "base": {"label": "main"}
        \\  },
        \\  {
        \\    "number": 11,
        \\    "title": "WIP: refactor",
        \\    "state": "open",
        \\    "user": {"login": "dave"},
        \\    "draft": true,
        \\    "html_url": "https://gitea.com/user/my-project/pulls/11",
        \\    "created_at": "2026-02-02T11:00:00Z",
        \\    "head": {"label": "dave:refactor-wip"},
        \\    "base": {"label": "develop"}
        \\  }
        \\]
    ;

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    const arr = parsed.value.array.items;
    try std.testing.expectEqual(@as(usize, 2), arr.len);

    const first = arr[0].object;
    try std.testing.expectEqual(@as(u64, 10), getU64(first, "number"));
    try std.testing.expectEqualStrings("New feature", getString(first, "title"));
    try std.testing.expectEqual(false, getBool(first, "draft"));

    const second = arr[1].object;
    try std.testing.expectEqual(@as(u64, 11), getU64(second, "number"));
    try std.testing.expectEqual(true, getBool(second, "draft"));
}

test "gitea: parse empty lists" {
    const empty_issues = "[]";
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, empty_issues, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 0), parsed.value.array.items.len);
}

test "gitea: parse single issue view" {
    const json =
        \\{
        \\  "number": 5,
        \\  "title": "Single issue",
        \\  "state": "open",
        \\  "user": {"login": "eve"},
        \\  "labels": [
        \\    {"name": "bug"}
        \\  ],
        \\  "html_url": "https://gitea.com/user/my-project/issues/5",
        \\  "created_at": "2026-03-01T08:00:00Z",
        \\  "body": "This is a single issue"
        \\}
    ;

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    const obj = parsed.value.object;
    try std.testing.expectEqual(@as(u64, 5), getU64(obj, "number"));
    try std.testing.expectEqualStrings("Single issue", getString(obj, "title"));
    try std.testing.expectEqualStrings("This is a single issue", getString(obj, "body"));
    try std.testing.expectEqual(@as(usize, 1), obj.get("labels").?.array.items.len);
}

test {
    _ = getString;
    _ = getU64;
    _ = getBool;
}
