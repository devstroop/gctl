const std = @import("std");

pub const env = @import("env.zig");
pub const keychain = @import("keychain.zig");
pub const oauth = @import("oauth.zig");

const config = @import("config");

/// Get a token for the given provider and account name.
/// Resolution order: env vars → keychain → config file.
/// Returns null if no token is found.
pub fn getToken(allocator: std.mem.Allocator, provider: []const u8, account: ?[]const u8) !?[]const u8 {
    // 1. Environment variables (highest priority)
    if (try env.getToken(allocator, provider)) |t| return t;

    // 2. OS keychain (requires account name)
    if (account) |acc| {
        if (try keychain.get(allocator, provider, acc)) |t| return t;
    }

    return null;
}

/// Prompt for a token on stdin (reads a line, trims whitespace).
fn promptToken(allocator: std.mem.Allocator, provider: []const u8) ![]const u8 {
    const stdin_file = std.fs.File.stdin();
    const stdout_file = std.fs.File.stdout();
    const prompt = try std.fmt.allocPrint(allocator, "Enter {s} token: ", .{provider});
    defer allocator.free(prompt);
    try stdout_file.writeAll(prompt);
    var rbuf: [4096]u8 = undefined;
    var reader = stdin_file.reader(&rbuf);
    const n = try reader.interface.readSliceShort(&rbuf);
    const line = std.mem.trim(u8, rbuf[0..n], "\r\n\t ");
    return try allocator.dupe(u8, line);
}

/// Prompt for an account name, returning the given default if input is empty.
fn promptAccount(allocator: std.mem.Allocator, default: []const u8) ![]const u8 {
    const stdin_file = std.fs.File.stdin();
    const stdout_file = std.fs.File.stdout();
    const prompt = try std.fmt.allocPrint(allocator, "Account name [default: {s}]: ", .{default});
    defer allocator.free(prompt);
    try stdout_file.writeAll(prompt);
    var rbuf: [256]u8 = undefined;
    var reader = stdin_file.reader(&rbuf);
    const n = try reader.interface.readSliceShort(&rbuf);
    const line = std.mem.trim(u8, rbuf[0..n], "\r\n\t ");
    if (line.len == 0) return allocator.dupe(u8, default);
    return try allocator.dupe(u8, line);
}

pub fn execLogin(stdout: anytype, stderr: anytype, allocator: std.mem.Allocator, provider_arg: ?[]const u8, account_arg: ?[]const u8) !void {
    const provider = provider_arg orelse {
        try stderr.interface.print("error: auth login requires a provider (github|gitlab)\n", .{});
        std.process.exit(1);
    };

    // Validate provider
    if (!std.mem.eql(u8, provider, "github") and !std.mem.eql(u8, provider, "gitlab") and !std.mem.eql(u8, provider, "gitea")) {
        try stderr.interface.print("error: unknown provider '{s}'\n", .{provider});
        std.process.exit(1);
    }

    // Check env var — warn if set
    const env_var_name = env.varName(provider);
    const existing_env = try env.getEnvVarOwned(allocator, env_var_name);
    defer if (existing_env) |e| allocator.free(e);
    if (existing_env != null) {
        try stdout.interface.print("  ⚠  {s} is already set — keychain token will be ignored while it's set.\n", .{env_var_name});
    }

    // Determine account name
    const account = if (account_arg) |a|
        try allocator.dupe(u8, a)
    else
        try promptAccount(allocator, "default");
    defer allocator.free(account);

    // Check if already stored
    if (try keychain.get(allocator, provider, account)) |_| {
        try stdout.interface.print("  Token already stored for {s} ({s}). Updating...\n", .{ provider, account });
    }

    // Get token: OAuth for GitHub, prompt for others
    const token = if (std.mem.eql(u8, provider, "github")) blk: {
        try stdout.interface.print("  Starting GitHub OAuth device flow...\n", .{});
        break :blk try oauth.loginDeviceFlow(allocator);
    } else blk: {
        break :blk try promptToken(allocator, provider);
    };
    defer allocator.free(token);

    // Store in keychain
    try keychain.store(allocator, provider, account, token);

    // Update config file
    var cfg = try config.read(allocator);
    // Add or update account entry
    var found = false;
    for (cfg.accounts, 0..) |*acc, i| {
        if (std.mem.eql(u8, acc.name, account) and std.mem.eql(u8, acc.provider, provider)) {
            found = true;
            _ = i;
        }
    }
    if (!found) {
        var new_accounts = try allocator.alloc(config.Account, cfg.accounts.len + 1);
        for (cfg.accounts, 0..) |a, i| {
            new_accounts[i] = a;
        }
        new_accounts[cfg.accounts.len] = .{ .name = account, .provider = provider };
        cfg.accounts = new_accounts;
    }
    try config.write(allocator, cfg);

    try stdout.interface.print("  ✓ Token stored for {s} ({s})\n", .{ provider, account });
}

pub fn execLogout(stdout: anytype, stderr: anytype, allocator: std.mem.Allocator, provider_arg: ?[]const u8, account_arg: ?[]const u8) !void {
    const provider = provider_arg orelse {
        try stderr.interface.print("error: auth logout requires a provider (github|gitlab)\n", .{});
        std.process.exit(1);
    };
    const account = account_arg orelse "default";

    try keychain.delete(allocator, provider, account);

    // Remove from config
    var cfg = try config.read(allocator);
    var kept = try std.ArrayList(config.Account).initCapacity(allocator, cfg.accounts.len);
    for (cfg.accounts) |a| {
        if (!(std.mem.eql(u8, a.name, account) and std.mem.eql(u8, a.provider, provider))) {
            try kept.append(allocator, a);
        }
    }
    cfg.accounts = try kept.toOwnedSlice(allocator);
    try config.write(allocator, cfg);

    try stdout.interface.print("  ✓ Token removed for {s} ({s})\n", .{ provider, account });
}

pub fn execList(stdout: anytype, allocator: std.mem.Allocator) !void {
    const cfg = try config.read(allocator);
    if (cfg.accounts.len == 0) {
        try stdout.interface.print("No accounts configured.\n", .{});
        try stdout.interface.print("Run 'gctl auth login <provider>' to add one.\n", .{});
        return;
    }
    try stdout.interface.print("Configured accounts:\n\n", .{});
    for (cfg.accounts) |a| {
        const env_var = env.varName(a.provider);
        const has_token = if (try env.getEnvVarOwned(allocator, env_var)) |t| blk: {
            allocator.free(t);
            break :blk " (env var active)";
        } else "";
        try stdout.interface.print("  {s:12} {s:8}{s}\n", .{ a.name, a.provider, has_token });
    }
}

pub fn execStatus(stdout: anytype, _: anytype, allocator: std.mem.Allocator, account_arg: ?[]const u8) !void {
    // Try to detect current provider from git context or account arg
    const cfg = try config.read(allocator);
    const account = account_arg orelse "default";

    // Find account in config
    const found = for (cfg.accounts) |a| {
        if (std.mem.eql(u8, a.name, account)) break a;
    } else null;

    try stdout.interface.print("Auth status:\n\n", .{});
    if (found) |acc| {
        const env_var = env.varName(acc.provider);
        const env_token = try env.getEnvVarOwned(allocator, env_var);
        defer if (env_token) |t| allocator.free(t);
        const keychain_token = try keychain.get(allocator, acc.provider, acc.name);
        try stdout.interface.print("  Provider:  {s}\n", .{acc.provider});
        try stdout.interface.print("  Account:   {s}\n", .{acc.name});
        try stdout.interface.print("  Token:     {s}\n", .{if (env_token != null) "env var" else if (keychain_token != null) "keychain" else "none"});
        if (acc.url) |u| try stdout.interface.print("  URL:       {s}\n", .{u});
    } else {
        try stdout.interface.print("  Account '{s}' not found in config.\n", .{account});
        try stdout.interface.print("  Run 'gctl auth list' to see configured accounts.\n", .{});
    }
}
