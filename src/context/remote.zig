const std = @import("std");

pub const ResolvedContext = struct {
    provider: []const u8,
    owner: []const u8,
    repo: []const u8,
    remote_name: []const u8,
    remote_url: []const u8,
    token_source: []const u8,

    pub fn deinit(self: *ResolvedContext, allocator: std.mem.Allocator) void {
        allocator.free(self.provider);
        allocator.free(self.owner);
        allocator.free(self.repo);
        allocator.free(self.remote_name);
        allocator.free(self.remote_url);
        allocator.free(self.token_source);
    }
};

pub fn contextsDeinit(ctxs: []ResolvedContext, allocator: std.mem.Allocator) void {
    for (ctxs) |*c| c.deinit(allocator);
    allocator.free(ctxs);
}

/// Run `git remote -v` and resolve all fetch remotes into contexts.
/// Returns error.NoGitRepo if not in a git repo.
/// Returns error.NoRemote if no remotes are configured.
/// Returns error.UnknownProvider if no remote matches a known provider
///   and no provider_override is given.
pub fn resolve(allocator: std.mem.Allocator, provider_override: ?[]const u8, provider_url: ?[]const u8) ![]ResolvedContext {
    _ = provider_url;
    var child = std.process.Child.init(&.{ "git", "remote", "-v" }, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();

    const stdout = child.stdout.?;
    const output = try stdout.readToEndAlloc(allocator, 4096);
    defer allocator.free(output);

    const term = try child.wait();
    if (term != .Exited or term.Exited != 0) return error.NoGitRepo;

    var list = try std.ArrayList(ResolvedContext).initCapacity(allocator, 4);
    errdefer {
        for (list.items) |*c| c.deinit(allocator);
        list.deinit(allocator);
    }

    var lines = std.mem.splitSequence(u8, output, "\n");
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (!std.mem.endsWith(u8, line, "(fetch)")) continue;

        var parts = std.mem.splitSequence(u8, line, "\t");
        const remote_name = parts.next() orelse continue;
        const url_part = parts.next() orelse continue;

        var url_split = std.mem.splitSequence(u8, url_part, " ");
        const remote_url = url_split.next() orelse continue;

        const provider = if (provider_override) |prov|
            prov
        else if (std.mem.indexOf(u8, remote_url, "github.com") != null or std.mem.indexOf(u8, remote_url, "github") != null)
            "github"
        else if (std.mem.indexOf(u8, remote_url, "gitlab.com") != null or std.mem.indexOf(u8, remote_url, "gitlab") != null)
            "gitlab"
        else if (std.mem.indexOf(u8, remote_url, "gitea.com") != null)
            "gitea"
        else
            "custom";

        const owner_repo = extractOwnerRepo(remote_url, allocator) orelse continue;

        try list.append(allocator, ResolvedContext{
            .provider = try allocator.dupe(u8, provider),
            .owner = owner_repo.owner,
            .repo = owner_repo.repo,
            .remote_name = try allocator.dupe(u8, remote_name),
            .remote_url = try allocator.dupe(u8, remote_url),
            .token_source = try allocator.dupe(u8, "env"),
        });
    }

    if (list.items.len == 0) return error.NoRemote;

    return list.toOwnedSlice(allocator);
}

fn extractOwnerRepo(url: []const u8, allocator: std.mem.Allocator) ?struct { owner: []const u8, repo: []const u8 } {
    if (std.mem.indexOfScalar(u8, url, '@')) |_| {
        if (std.mem.indexOfScalar(u8, url, ':')) |colon| {
            const path = url[colon + 1 ..];
            const clean_path = if (std.mem.endsWith(u8, path, ".git"))
                path[0 .. path.len - 4]
            else
                path;
            if (std.mem.indexOfScalar(u8, clean_path, '/')) |slash| {
                return .{
                    .owner = allocator.dupe(u8, clean_path[0..slash]) catch return null,
                    .repo = allocator.dupe(u8, clean_path[slash + 1 ..]) catch return null,
                };
            }
        }
    }
    if (std.mem.indexOf(u8, url, "://")) |_| {
        var rest = url;
        if (std.mem.indexOf(u8, rest, "://")) |scheme_end| {
            rest = rest[scheme_end + 3 ..];
        }
        if (std.mem.indexOfScalar(u8, rest, '/')) |first_slash| {
            rest = rest[first_slash + 1 ..];
        }
        const clean_rest = if (std.mem.endsWith(u8, rest, ".git"))
            rest[0 .. rest.len - 4]
        else
            rest;
        if (std.mem.indexOfScalar(u8, clean_rest, '/')) |slash| {
            return .{
                .owner = allocator.dupe(u8, clean_rest[0..slash]) catch return null,
                .repo = allocator.dupe(u8, clean_rest[slash + 1 ..]) catch return null,
            };
        }
    }
    return null;
}

/// Parse a git remote URL and extract provider, owner, and repo.
/// Returns null if the URL doesn't match any known provider.
pub fn parseRemote(url: []const u8, allocator: std.mem.Allocator) ?struct { provider: []const u8, owner: []const u8, repo: []const u8 } {
    if (std.mem.indexOf(u8, url, "github.com") != null or
        std.mem.indexOf(u8, url, "github") != null)
    {
        const owner_repo = extractOwnerRepo(url, allocator) orelse return null;
        return .{
            .provider = allocator.dupe(u8, "github") catch return null,
            .owner = owner_repo.owner,
            .repo = owner_repo.repo,
        };
    }
    if (std.mem.indexOf(u8, url, "gitlab.com") != null or
        std.mem.indexOf(u8, url, "gitlab") != null)
    {
        const owner_repo = extractOwnerRepo(url, allocator) orelse return null;
        return .{
            .provider = allocator.dupe(u8, "gitlab") catch return null,
            .owner = owner_repo.owner,
            .repo = owner_repo.repo,
        };
    }
    if (std.mem.indexOf(u8, url, "gitea.com") != null) {
        const owner_repo = extractOwnerRepo(url, allocator) orelse return null;
        return .{
            .provider = allocator.dupe(u8, "gitea") catch return null,
            .owner = owner_repo.owner,
            .repo = owner_repo.repo,
        };
    }
    return null;
}

test {
    _ = ResolvedContext;
    _ = parseRemote;
    _ = resolve;
}
