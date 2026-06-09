const std = @import("std");

const Response = struct {
    body: []const u8,
    status: u16,
};

fn postForm(allocator: std.mem.Allocator, url: []const u8, form_body: []const u8) !Response {
    const uri = try std.Uri.parse(url);
    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    var extra_headers = [_]std.http.Header{
        .{ .name = "Accept", .value = "application/json" },
        .{ .name = "User-Agent", .value = "gctl/0.1.0" },
        .{ .name = "Content-Type", .value = "application/x-www-form-urlencoded" },
    };

    var req = try client.request(.POST, uri, .{ .extra_headers = &extra_headers });
    defer req.deinit();

    try req.sendBodyComplete(@constCast(form_body));

    var redirect_buf: [4 * 1024]u8 = undefined;
    var response = try req.receiveHead(&redirect_buf);

    var transfer_buf: [64]u8 = undefined;
    var reader = response.reader(&transfer_buf);
    const body = try reader.allocRemaining(allocator, std.io.Limit.limited(10 * 1024 * 1024));

    return Response{
        .body = body,
        .status = @intFromEnum(response.head.status),
    };
}

/// Default GitHub OAuth client ID.
const default_client_id = "Iv23li1CQnzR31KQ11n7";

/// GitHub device flow OAuth.
pub fn loginDeviceFlow(allocator: std.mem.Allocator) ![]const u8 {
    const env_client_id = try @import("env.zig").getEnvVarOwned(allocator, "GITHUB_CLIENT_ID");
    const client_id = env_client_id orelse default_client_id;
    defer if (env_client_id != null) allocator.free(client_id);

    // Step 1: Request device code
    const device_code_url = "https://github.com/login/device/code";
    const device_body = try std.fmt.allocPrint(allocator, "client_id={s}&scope=repo", .{client_id});
    defer allocator.free(device_body);

    const device_resp = try postForm(allocator, device_code_url, device_body);
    defer allocator.free(device_resp.body);

    var device_parsed = try std.json.parseFromSlice(std.json.Value, allocator, device_resp.body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true });
    defer device_parsed.deinit();
    const device_obj = device_parsed.value.object;

    const user_code = device_obj.get("user_code").?.string;
    const device_code = device_obj.get("device_code").?.string;
    const verification_uri = if (device_obj.get("verification_uri")) |v| v.string else "https://github.com/login/device";
    const interval: u64 = if (device_obj.get("interval")) |i| @intCast(i.integer) else 5;

    // Step 2: Show user the code
    const stdout = std.fs.File.stdout();
    try stdout.writeAll("\n");
    try stdout.writeAll("  +---------------------------------------------+\n");
    try stdout.writeAll("  |  GitHub Device Login                        |\n");
    try stdout.writeAll("  |                                             |\n");
    try stdout.writeAll("  |  Visit:                                     |\n");
    try stdout.writeAll("  |    ");
    try stdout.writeAll(verification_uri);
    try stdout.writeAll("\n");
    try stdout.writeAll("  |                                             |\n");
    try stdout.writeAll("  |  Enter code:                                |\n");
    try stdout.writeAll("  |    ");
    try stdout.writeAll(user_code);
    try stdout.writeAll("\n");
    try stdout.writeAll("  |                                             |\n");
    try stdout.writeAll("  |  (waiting for browser authorization...)      |\n");
    try stdout.writeAll("  +---------------------------------------------+\n");
    try stdout.writeAll("\n");

    // Step 3: Poll for access token
    const token_url = "https://github.com/login/oauth/access_token";
    var token_body_buf: [1024]u8 = undefined;

    while (true) {
        std.Thread.sleep(interval * std.time.ns_per_s);

        const token_body = try std.fmt.bufPrint(&token_body_buf, "client_id={s}&device_code={s}&grant_type=urn:ietf:params:oauth:grant_type:device_code", .{ client_id, device_code });

        const token_resp = try postForm(allocator, token_url, token_body);
        defer allocator.free(token_resp.body);

        var token_parsed = try std.json.parseFromSlice(std.json.Value, allocator, token_resp.body, .{ .allocate = .alloc_always, .ignore_unknown_fields = true });
        defer token_parsed.deinit();
        const token_obj = token_parsed.value.object;

        if (token_obj.get("access_token")) |t| {
            const access_token = try allocator.dupe(u8, t.string);
            try stdout.writeAll("  + Authorization successful!\n\n");
            return access_token;
        }

        if (token_obj.get("error")) |err| {
            const err_str = err.string;
            if (std.mem.eql(u8, err_str, "authorization_pending")) continue;
            if (std.mem.eql(u8, err_str, "slow_down")) continue;
            try stdout.writeAll("  x Authorization failed: ");
            try stdout.writeAll(err_str);
            try stdout.writeAll("\n");
            return error.OAuthFailed;
        }
    }
}

test {
    _ = loginDeviceFlow;
}
