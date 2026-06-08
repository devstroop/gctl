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
    _ = allocator;
    _ = cfg;
    @compileError("TODO: implement config.write");
}

test {
    _ = Account;
    _ = Config;
    _ = Defaults;
}
