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
    const home = std.posix.getenv("HOME") orelse {
        return Config{ .accounts = &.{}, .defaults = .{} };
    };

    const config_dir = try std.fs.path.join(allocator, &.{ home, ".gctl" });
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

/// Write config to ~/.gctl/config.json.
pub fn write(allocator: std.mem.Allocator, cfg: Config) !void {
    _ = allocator;
    _ = cfg;
    @compileError("TODO: implement config.write");
}

test "read: returns default config when no file exists" {
    const allocator = std.testing.allocator;
    const orig_home = std.posix.getenv("HOME");
    defer if (orig_home) |h| std.posix.setenv("HOME", h) catch {};

    // Use a temp dir that won't have .gctl/config.json
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
    const allocator = std.testing.allocator;
    const orig_home = std.posix.getenv("HOME");
    defer if (orig_home) |h| std.posix.setenv("HOME", h) catch {};

    const tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    const tmp_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_path);

    // Create ~/.gctl/ directory and config.json
    const gctl_dir = try std.fs.path.join(allocator, &.{ tmp_path, ".gctl" });
    defer allocator.free(gctl_dir);
    try std.fs.makeDirAbsolute(gctl_dir);

    const config_path = try std.fs.path.join(allocator, &.{ gctl_dir, "config.json" });
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

