const std = @import("std");

/// An account entry in the config file.
pub const Account = struct {
    name: []const u8,
    provider: []const u8,
    url: ?[]const u8 = null, // optional, for self-hosted instances
};

/// Full config schema.
pub const Config = struct {
    accounts: []Account,
    defaults: Defaults,
};

pub const Defaults = struct {
    provider: []const u8 = "auto",
};

/// Read config from ~/.gctl/config.json.
/// Returns a default config if the file doesn't exist.
pub fn read(allocator: std.mem.Allocator) !Config {
    _ = allocator;
    @compileError("TODO: implement config.read");
}

/// Write config to ~/.gctl/config.json.
pub fn write(allocator: std.mem.Allocator, cfg: Config) !void {
    const home = std.posix.getenv("HOME") orelse return error.NoHomeDirectory;

    const config_dir = try std.fs.path.join(allocator, &.{ home, ".gctl" });
    defer allocator.free(config_dir);

    const config_path = try std.fs.path.join(allocator, &.{ config_dir, "config.json" });
    defer allocator.free(config_path);

    // Create directory if it doesn't exist
    std.fs.makeDirAbsolute(config_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => |e| return e,
    };

    // Serialize to JSON
    var json_buf = std.ArrayList(u8).init(allocator);
    defer json_buf.deinit();

    try std.json.stringify(cfg, .{ .whitespace = .{ .indent = .{ .space = 2 } } }, json_buf.writer());

    // Write atomically: write to temp, then rename
    const tmp_path = try std.fmt.allocPrint(allocator, "{s}.tmp", .{config_path});
    defer allocator.free(tmp_path);

    try std.fs.writeFileAbsolute(tmp_path, json_buf.items);
    try std.fs.renameAbsolute(tmp_path, config_path);
}

test "write: creates config file with correct content" {
    const allocator = std.testing.allocator;
    const orig_home = std.posix.getenv("HOME");
    defer if (orig_home) |h| std.posix.setenv("HOME", h) catch {};

    const tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    try std.posix.setenv("HOME", tmp_path);

    const cfg = Config{
        .accounts = &.{
            Account{ .name = "personal", .provider = "github" },
            Account{ .name = "work", .provider = "gitlab", .url = "https://gitlab.company.com" },
        },
        .defaults = .{ .provider = "auto" },
    };

    try write(allocator, cfg);

    // Read back and verify
    const config_path = try std.fs.path.join(allocator, &.{ tmp_path, ".gctl", "config.json" });
    defer allocator.free(config_path);

    const content = try std.fs.readFileAbsoluteAlloc(config_path, allocator, 1024 * 16);
    defer allocator.free(content);

    // Verify it's valid JSON
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, content, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    const obj = parsed.value.object;
    try std.testing.expect(obj.get("accounts") != null);
    try std.testing.expect(obj.get("defaults") != null);

    const accounts = obj.get("accounts").?.array;
    try std.testing.expectEqual(@as(usize, 2), accounts.items.len);

    try std.testing.expectEqualStrings("personal", accounts.items[0].object.get("name").?.string);
    try std.testing.expectEqualStrings("github", accounts.items[0].object.get("provider").?.string);

    try std.testing.expectEqualStrings("work", accounts.items[1].object.get("name").?.string);
    try std.testing.expectEqualStrings("gitlab", accounts.items[1].object.get("provider").?.string);
    try std.testing.expectEqualStrings("https://gitlab.company.com", accounts.items[1].object.get("url").?.string);
}

test "write: creates directory if it doesn't exist" {
    const allocator = std.testing.allocator;
    const orig_home = std.posix.getenv("HOME");
    defer if (orig_home) |h| std.posix.setenv("HOME", h) catch {};

    const tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    try std.posix.setenv("HOME", tmp_path);

    const cfg = Config{
        .accounts = &.{},
        .defaults = .{ .provider = "gitlab" },
    };

    try write(allocator, cfg);

    // Verify directory was created
    const gctl_dir = try std.fs.path.join(allocator, &.{ tmp_path, ".gctl" });
    defer allocator.free(gctl_dir);
    const dir = std.fs.openDirAbsolute(gctl_dir, .{}) catch {
        return error.TestDirNotCreated;
    };
    dir.close();

    // Verify file exists
    const config_path = try std.fs.path.join(allocator, &.{ gctl_dir, "config.json" });
    defer allocator.free(config_path);
    const file = try std.fs.openFileAbsolute(config_path, .{ .mode = .read_only });
    file.close();
}

test "write: respects empty accounts" {
    const allocator = std.testing.allocator;
    const orig_home = std.posix.getenv("HOME");
    defer if (orig_home) |h| std.posix.setenv("HOME", h) catch {};

    const tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    try std.posix.setenv("HOME", tmp_path);

    const cfg = Config{
        .accounts = &.{},
        .defaults = .{ .provider = "auto" },
    };

    try write(allocator, cfg);

    const config_path = try std.fs.path.join(allocator, &.{ tmp_path, ".gctl", "config.json" });
    defer allocator.free(config_path);

    const content = try std.fs.readFileAbsoluteAlloc(config_path, allocator, 1024 * 16);
    defer allocator.free(content);

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, content, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    const accounts = parsed.value.object.get("accounts").?.array;
    try std.testing.expectEqual(@as(usize, 0), accounts.items.len);
}
