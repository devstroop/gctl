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

/// Run `git remote -v` and resolve provider context.
/// Returns error.NoGitRepo if not in a git repo.
/// Returns error.NoRemote if no remotes are configured.
/// Returns error.UnknownProvider if no remote matches a known provider
///   and no provider_override is given.
pub fn resolve(allocator: std.mem.Allocator, provider_override: ?[]const u8, provider_url: ?[]const u8) !ResolvedContext {
    _ = provider_url; // consumed by providers.execute, not by context
    // v0.1: minimal implementation — runs git remote -v and parses the first remote
    var child = std.process.Child.init(&.{ "git", "remote", "-v" }, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();

    const stdout = child.stdout.?;
    const output = try stdout.readToEndAlloc(allocator, 4096);
    defer allocator.free(output);

    const term = try child.wait();
    if (term != .Exited or term.Exited != 0) return error.NoGitRepo;

    // Parse first line of "git remote -v" output
    // Format: "origin\tgit@github.com:owner/repo.git (fetch)"
    // or:     "origin\thttps://github.com/owner/repo.git (fetch)"
    var lines = std.mem.splitSequence(u8, output, "\n");
    const first_line = lines.next() orelse return error.NoRemote;
    if (first_line.len == 0) return error.NoRemote;

    // Split on \t to get name and url
    var parts = std.mem.splitSequence(u8, first_line, "\t");
    const remote_name = parts.next() orelse return error.NoRemote;
    const url_part = parts.next() orelse return error.NoRemote;

    // Split url_part on space to drop the "(fetch)" part
    var url_split = std.mem.splitSequence(u8, url_part, " ");
    const remote_url = url_split.next() orelse return error.NoRemote;

    // Parse the URL to extract provider, owner, repo
    // If provider overridden, use it regardless of what parseRemote detects
    if (provider_override) |prov| {
        const owner_repo = extractOwnerRepo(remote_url, allocator) orelse return error.UnknownProvider;
        return ResolvedContext{
            .provider = try allocator.dupe(u8, prov),
            .owner = owner_repo.owner,
            .repo = owner_repo.repo,
            .remote_name = try allocator.dupe(u8, remote_name),
            .remote_url = try allocator.dupe(u8, remote_url),
            .token_source = try allocator.dupe(u8, "env"),
        };
    }

    const parsed = parseRemote(remote_url, allocator) orelse {
        // Auto-detect as custom when remote exists but doesn't match known providers
        const owner_repo = extractOwnerRepo(remote_url, allocator) orelse return error.UnknownProvider;
        return ResolvedContext{
            .provider = try allocator.dupe(u8, "custom"),
            .owner = owner_repo.owner,
            .repo = owner_repo.repo,
            .remote_name = try allocator.dupe(u8, remote_name),
            .remote_url = try allocator.dupe(u8, remote_url),
            .token_source = try allocator.dupe(u8, "env"),
        };
    };

    return ResolvedContext{
        .provider = parsed.provider,
        .owner = parsed.owner,
        .repo = parsed.repo,
        .remote_name = try allocator.dupe(u8, remote_name),
        .remote_url = try allocator.dupe(u8, remote_url),
        .token_source = try allocator.dupe(u8, "env"),
    };
}

fn extractOwnerRepo(url: []const u8, allocator: std.mem.Allocator) ?struct { owner: []const u8, repo: []const u8 } {
    // Handle git@host:owner/repo.git format
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
    // Handle https://host/owner/repo.git format
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
    // Detect provider by URL pattern
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
