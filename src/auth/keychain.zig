const std = @import("std");

const service_name = "gitctl";

fn keyLabel(allocator: std.mem.Allocator, provider: []const u8, account: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}:{s}", .{ provider, account });
}

/// Store a token in the OS keychain.
/// macOS: `security add-generic-password -s gitctl -a <label> -w <token> -U`
/// Linux: `secret-tool store --label=gitctl service gitctl account <label>` (reads token from stdin)
pub fn store(allocator: std.mem.Allocator, provider: []const u8, account: []const u8, token: []const u8) !void {
    const label = try keyLabel(allocator, provider, account);
    defer allocator.free(label);

    if (comptime isMacOS()) {
        const argv = &.{ "security", "add-generic-password", "-s", service_name, "-a", label, "-w", token, "-U" };
        const result = try std.process.Child.run(.{ .allocator = allocator, .argv = argv });
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);
        if (result.term.Exited != 0) return error.KeychainStoreFailed;
    } else if (comptime isLinux()) {
        const argv = &.{ "secret-tool", "store", "--label=gitctl", "service", service_name, "account", label };
        var child = std.process.Child.init(argv, allocator);
        child.stdin_behavior = .Pipe;
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;
        try child.spawn();
        if (child.stdin) |stdin| {
            try stdin.writeAll(token);
            try stdin.writeAll("\n");
        }
        const result = try child.wait();
        if (result.Exited != 0) return error.KeychainStoreFailed;
    } else {
        return error.UnsupportedPlatform;
    }
}

/// Retrieve a token from the OS keychain.
/// macOS: `security find-generic-password -s gitctl -a <label> -w`
/// Linux: `secret-tool lookup service gitctl account <label>`
pub fn get(allocator: std.mem.Allocator, provider: []const u8, account: []const u8) !?[]const u8 {
    const label = try keyLabel(allocator, provider, account);
    defer allocator.free(label);

    if (comptime isMacOS()) {
        const argv = &.{ "security", "find-generic-password", "-s", service_name, "-a", label, "-w" };
        const result = try std.process.Child.run(.{ .allocator = allocator, .argv = argv });
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);
        if (result.term.Exited != 0) return null;
        return std.mem.trim(u8, result.stdout, "\n\r");
    } else if (comptime isLinux()) {
        const argv = &.{ "secret-tool", "lookup", "service", service_name, "account", label };
        const result = try std.process.Child.run(.{ .allocator = allocator, .argv = argv });
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);
        if (result.term.Exited != 0) return null;
        return std.mem.trim(u8, result.stdout, "\n\r");
    } else {
        return error.UnsupportedPlatform;
    }
}

/// Delete a token from the OS keychain.
/// macOS: `security delete-generic-password -s gitctl -a <label>`
/// Linux: `secret-tool clear service gitctl account <label>`
pub fn delete(allocator: std.mem.Allocator, provider: []const u8, account: []const u8) !void {
    const label = try keyLabel(allocator, provider, account);
    defer allocator.free(label);

    if (comptime isMacOS()) {
        const argv = &.{ "security", "delete-generic-password", "-s", service_name, "-a", label };
        const result = try std.process.Child.run(.{ .allocator = allocator, .argv = argv });
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);
        if (result.term.Exited != 0) return error.KeychainDeleteFailed;
    } else if (comptime isLinux()) {
        const argv = &.{ "secret-tool", "clear", "service", service_name, "account", label };
        const result = try std.process.Child.run(.{ .allocator = allocator, .argv = argv });
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);
        if (result.term.Exited != 0) return error.KeychainDeleteFailed;
    } else {
        return error.UnsupportedPlatform;
    }
}

fn isMacOS() bool {
    return comptime @import("builtin").target.os.tag == .macos;
}

fn isLinux() bool {
    return comptime @import("builtin").target.os.tag == .linux;
}

test {
    _ = store;
    _ = get;
    _ = delete;
}
