const std = @import("std");

const MAX_RESPONSE = 10 * 1024 * 1024; // 10MB

pub const Response = struct {
    body: []const u8,
    status: u16,
};

fn request(allocator: std.mem.Allocator, method: std.http.Method, url: []const u8, token: ?[]const u8, req_body: ?[]const u8) !Response {
    const uri = try std.Uri.parse(url);

    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    // Build extra headers (must outlive the request)
    var extra_headers: [4]std.http.Header = undefined;
    var extra_count: usize = 0;
    extra_headers[extra_count] = .{ .name = "Accept", .value = "application/vnd.github+json" };
    extra_count += 1;
    extra_headers[extra_count] = .{ .name = "User-Agent", .value = "gctl/0.1.0" };
    extra_count += 1;

    // Build authorization header if token provided
    var auth_buf: [256]u8 = undefined;
    var headers: std.http.Client.Request.Headers = .{};
    if (token) |t| {
        const auth_value = try std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{t});
        headers.authorization = .{ .override = auth_value };
    }

    var req = try client.request(method, uri, .{
        .headers = headers,
        .extra_headers = extra_headers[0..extra_count],
    });
    defer req.deinit();

    // Send request
    if (req_body) |b| {
        try req.sendBodyComplete(@constCast(b));
    } else {
        try req.sendBodiless();
    }

    // Receive response
    var redirect_buf: [8 * 1024]u8 = undefined;
    var response = try req.receiveHead(&redirect_buf);

    // Read body
    var transfer_buf: [64]u8 = undefined;
    var reader = response.reader(&transfer_buf);

    const body = try reader.allocRemaining(allocator, std.io.Limit.limited(MAX_RESPONSE));
    return Response{
        .body = body,
        .status = @intFromEnum(response.head.status),
    };
}

/// Make an HTTP GET request to the given URL with a Bearer token.
/// Returns the response body and status code.
pub fn get(allocator: std.mem.Allocator, url: []const u8, token: ?[]const u8) !Response {
    return request(allocator, .GET, url, token, null);
}

/// Make an HTTP POST request with a JSON body.
pub fn post(allocator: std.mem.Allocator, url: []const u8, token: ?[]const u8, body: []const u8) !Response {
    return request(allocator, .POST, url, token, body);
}

/// Make an HTTP PATCH request with a JSON body.
pub fn patch(allocator: std.mem.Allocator, url: []const u8, token: ?[]const u8, body: []const u8) !Response {
    return request(allocator, .PATCH, url, token, body);
}

/// Make an HTTP DELETE request.
pub fn delete(allocator: std.mem.Allocator, url: []const u8, token: ?[]const u8) !Response {
    return request(allocator, .DELETE, url, token, null);
}

/// Make an HTTP PUT request.
pub fn put(allocator: std.mem.Allocator, url: []const u8, token: ?[]const u8, body: []const u8) !Response {
    return request(allocator, .PUT, url, token, body);
}

test {
    _ = get;
    _ = post;
    _ = patch;
    _ = delete;
    _ = put;
}
