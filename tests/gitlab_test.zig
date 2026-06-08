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
