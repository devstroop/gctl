const std = @import("std");
const types = @import("types.zig");

// Gitea/Forgejo provider
// All vtables are null for now.

pub const repo_vtable: ?types.RepoVtable = null;
pub const issue_vtable: ?types.IssueVtable = null;
pub const pr_vtable: ?types.PRVtable = null;

test {
    _ = repo_vtable;
    _ = issue_vtable;
    _ = pr_vtable;
}
