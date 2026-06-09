const std = @import("std");

fn homeDir(allocator: std.mem.Allocator) !?[]const u8 {
    if (comptime @import("builtin").target.os.tag == .windows) {
        return std.process.getEnvVarOwned(allocator, "USERPROFILE") catch |err| switch (err) {
            error.EnvironmentVariableNotFound => return null,
            else => |e| return e,
        };
    } else {
        return std.process.getEnvVarOwned(allocator, "HOME") catch |err| switch (err) {
            error.EnvironmentVariableNotFound => return null,
            else => |e| return e,
        };
    }
}

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

/// Read config from ~/.gitctl/config.json.
/// Returns a default config if the file doesn't exist.
pub fn read(allocator: std.mem.Allocator) !Config {
    const home_buf = try homeDir(allocator);
    const home = home_buf orelse return Config{ .accounts = &.{}, .defaults = .{} };
    defer allocator.free(home_buf.?);

    const config_dir = try std.fs.path.join(allocator, &.{ home, ".gitctl" });
    defer allocator.free(config_dir);

    const config_path = try std.fs.path.join(allocator, &.{ config_dir, "config.json" });
    defer allocator.free(config_path);

    const file = std.fs.openFileAbsolute(config_path, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => return Config{ .accounts = &.{}, .defaults = .{} },
        else => |e| return e,
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 16);
    defer allocator.free(content);

    var parsed = try std.json.parseFromSlice(Config, allocator, content, .{ .allocate = .alloc_always, .ignore_unknown_fields = true });
    defer parsed.deinit();

    return parsed.value;
}

/// Write config to ~/.gitctl/config.json.
pub fn write(allocator: std.mem.Allocator, cfg: Config) !void {
    const home_buf = try homeDir(allocator);
    const home = home_buf orelse return error.NoHomeDirectory;
    defer allocator.free(home_buf.?);

    const config_dir = try std.fs.path.join(allocator, &.{ home, ".gitctl" });
    defer allocator.free(config_dir);

    const config_path = try std.fs.path.join(allocator, &.{ config_dir, "config.json" });
    defer allocator.free(config_path);

    // Create directory if it doesn't exist
    std.fs.makeDirAbsolute(config_dir) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => |e| return e,
    };

    // Serialize to JSON
    const json_bytes = try std.json.Stringify.valueAlloc(allocator, cfg, .{});
    defer allocator.free(json_bytes);

    // Write atomically: write to temp, then rename
    const tmp_path = try std.fmt.allocPrint(allocator, "{s}.tmp", .{config_path});
    defer allocator.free(tmp_path);

    var tmp_file = try std.fs.createFileAbsolute(tmp_path, .{ .read = false });
    defer tmp_file.close();
    try tmp_file.writeAll(json_bytes);
    try std.fs.renameAbsolute(tmp_path, config_path);
}

test "read: returns default config when no file exists" {
    if (@import("builtin").target.os.tag == .windows) return error.SkipZigTest;
    const allocator = std.testing.allocator;
    const orig_home = std.posix.getenv("HOME");
    defer if (orig_home) |h| std.posix.setenv("HOME", h) catch {};

    const tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    try std.posix.setenv("HOME", tmp_path);

    const cfg = try read(allocator);
    try std.testing.expectEqual(@as(usize, 0), cfg.accounts.len);
    try std.testing.expectEqualStrings("auto", cfg.defaults.provider);
}

test "read: parses config file correctly" {
    if (@import("builtin").target.os.tag == .windows) return error.SkipZigTest;
    const allocator = std.testing.allocator;
    const orig_home = std.posix.getenv("HOME");
    defer if (orig_home) |h| std.posix.setenv("HOME", h) catch {};

    const tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    const gitctl_dir = try std.fs.path.join(allocator, &.{ tmp_path, ".gitctl" });
    defer allocator.free(gitctl_dir);
    try std.fs.makeDirAbsolute(gitctl_dir);

    const config_path = try std.fs.path.join(allocator, &.{ gitctl_dir, "config.json" });
    defer allocator.free(config_path);

    const config_content =
        \\{
        \\  "accounts": [
        \\    {"name": "personal", "provider": "github"},
        \\    {"name": "work", "provider": "gitlab", "url": "https://gitlab.company.com"}
        \\  ],
        \\  "defaults": {"provider": "auto"}
        \\}
    ;
    try std.fs.writeFileAbsolute(config_path, config_content);

    try std.posix.setenv("HOME", tmp_path);

    const cfg = try read(allocator);
    try std.testing.expectEqual(@as(usize, 2), cfg.accounts.len);

    try std.testing.expectEqualStrings("personal", cfg.accounts[0].name);
    try std.testing.expectEqualStrings("github", cfg.accounts[0].provider);
    try std.testing.expect(cfg.accounts[0].url == null);

    try std.testing.expectEqualStrings("work", cfg.accounts[1].name);
    try std.testing.expectEqualStrings("gitlab", cfg.accounts[1].provider);
    try std.testing.expectEqualStrings("https://gitlab.company.com", cfg.accounts[1].url.?);

    try std.testing.expectEqualStrings("auto", cfg.defaults.provider);
}

test "write: creates config file with correct content" {
    if (@import("builtin").target.os.tag == .windows) return error.SkipZigTest;
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

    const config_path = try std.fs.path.join(allocator, &.{ tmp_path, ".gitctl", "config.json" });
    defer allocator.free(config_path);

    const content = try std.fs.readFileAbsoluteAlloc(config_path, allocator, 1024 * 16);
    defer allocator.free(content);

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
    if (@import("builtin").target.os.tag == .windows) return error.SkipZigTest;
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

    const gitctl_dir = try std.fs.path.join(allocator, &.{ tmp_path, ".gitctl" });
    defer allocator.free(gitctl_dir);
    const dir = std.fs.openDirAbsolute(gitctl_dir, .{}) catch {
        return error.TestDirNotCreated;
    };
    dir.close();

    const config_path = try std.fs.path.join(allocator, &.{ gitctl_dir, "config.json" });
    defer allocator.free(config_path);
    const file = try std.fs.openFileAbsolute(config_path, .{ .mode = .read_only });
    file.close();
}

test "write: respects empty accounts" {
    if (@import("builtin").target.os.tag == .windows) return error.SkipZigTest;
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

    const config_path = try std.fs.path.join(allocator, &.{ tmp_path, ".gitctl", "config.json" });
    defer allocator.free(config_path);

    const content = try std.fs.readFileAbsoluteAlloc(config_path, allocator, 1024 * 16);
    defer allocator.free(content);

    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, content, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    const accounts = parsed.value.object.get("accounts").?.array;
    try std.testing.expectEqual(@as(usize, 0), accounts.items.len);
}
