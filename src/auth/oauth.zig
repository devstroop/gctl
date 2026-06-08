const std = @import("std");

/// GitHub device flow OAuth.
/// 1. POST to https://github.com/login/device/code
/// 2. Show user the verification URL and code
/// 3. Poll POST https://github.com/login/oauth/access_token until complete
pub fn loginDeviceFlow(allocator: std.mem.Allocator) ![]const u8 {
    _ = allocator;
    @compileError("TODO: implement oauth.loginDeviceFlow (v1.0)");
}

test {
    _ = loginDeviceFlow;
}
