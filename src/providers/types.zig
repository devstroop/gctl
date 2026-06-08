const std = @import("std");
const http = @import("http");

// ── Capability enum ────────────────────────────────────────────────────────

pub const Capability = enum {
    repos,
    issues,
    prs,
    releases,
    pipelines,
};

// ── Shared response types ──────────────────────────────────────────────────

pub const RepoInfo = struct {
    name: []const u8,
    full_name: []const u8,
    description: []const u8,
    url: []const u8,
    default_branch: []const u8,
    stars: u64,
    forks: u64,
    open_issues: u64,
    visibility: []const u8,
};

pub const IssueInfo = struct {
    number: u64,
    title: []const u8,
    state: []const u8,
    author: []const u8,
    labels: []const []const u8,
    url: []const u8,
    created_at: []const u8,
    body: []const u8,
};

pub const PullRequestInfo = struct {
    number: u64,
    title: []const u8,
    state: []const u8,
    author: []const u8,
    draft: bool,
    url: []const u8,
    created_at: []const u8,
    source_branch: []const u8,
    target_branch: []const u8,
};

pub const ReleaseInfo = struct {
    tag_name: []const u8,
    name: []const u8,
    body: []const u8,
    draft: bool,
    prerelease: bool,
    url: []const u8,
    created_at: []const u8,
};

pub const RunInfo = struct {
    id: u64,
    name: []const u8,
    status: []const u8,
    conclusion: []const u8,
    branch: []const u8,
    url: []const u8,
    created_at: []const u8,
};

// ── Vtable types ───────────────────────────────────────────────────────────

pub const RepoVtable = struct {
    view: *const fn (allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8) anyerror!RepoInfo,
};

pub const IssueVtable = struct {
    list: *const fn (allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8) anyerror![]IssueInfo,
    view: *const fn (allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, number: u64) anyerror!IssueInfo,
};

pub const PRVtable = struct {
    list: *const fn (allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8) anyerror![]PullRequestInfo,
    view: *const fn (allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, number: u64) anyerror!PullRequestInfo,
};

pub const ReleaseVtable = struct {
    list: *const fn (allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8) anyerror![]ReleaseInfo,
    view: *const fn (allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, tag: []const u8) anyerror!ReleaseInfo,
};

pub const PipelineVtable = struct {
    list: *const fn (allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8) anyerror![]RunInfo,
    view: *const fn (allocator: std.mem.Allocator, token: []const u8, owner: []const u8, repo: []const u8, id: u64) anyerror!RunInfo,
};

// ── Provider descriptor ─────────────────────────────────────────────────────

pub const Provider = struct {
    name: []const u8,
    base_url: []const u8,
    repos: ?RepoVtable = null,
    issues: ?IssueVtable = null,
    prs: ?PRVtable = null,
    releases: ?ReleaseVtable = null,
    pipelines: ?PipelineVtable = null,
};

test {
    _ = Capability;
    _ = RepoInfo;
    _ = IssueInfo;
    _ = PullRequestInfo;
    _ = ReleaseInfo;
    _ = RunInfo;
    _ = RepoVtable;
    _ = IssueVtable;
    _ = PRVtable;
    _ = ReleaseVtable;
    _ = PipelineVtable;
    _ = Provider;
}
