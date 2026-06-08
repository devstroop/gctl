const std = @import("std");

/// Store a token in the OS keychain.
/// macOS: uses `security add-generic-password`
/// Linux: uses `secret-tool store`
pub fn store(allocator: std.mem.Allocator, provider: []const u8, account: []const u8, token: []const u8) !void {
    _ = allocator;
    _ = provider;
    _ = account;
    _ = token;
    @compileError("TODO: implement keychain.store (v1.0)");
}

/// Retrieve a token from the OS keychain.
pub fn get(allocator: std.mem.Allocator, provider: []const u8, account: []const u8) !?[]const u8 {
    _ = allocator;
    _ = provider;
    _ = account;
    @compileError("TODO: implement keychain.get (v1.0)");
}

/// Delete a token from the OS keychain.
pub fn delete(allocator: std.mem.Allocator, provider: []const u8, account: []const u8) !void {
    _ = allocator;
    _ = provider;
    _ = account;
    @compileError("TODO: implement keychain.delete (v1.0)");
}

test {
    _ = store;
    _ = get;
    _ = delete;
}
