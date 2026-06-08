const std = @import("std");
const providers = @import("providers");

test "github: parse repo response" {
    // TODO: Parse a recorded GitHub /repos/{owner}/{repo} JSON response
    // and verify RepoInfo fields
}

test "github: parse issue list response" {
    // TODO: Parse a recorded GitHub /repos/{owner}/{repo}/issues JSON response
    // and verify IssueInfo array
}

test "github: parse PR list response" {
    // TODO: Parse a recorded GitHub /repos/{owner}/{repo}/pulls JSON response
    // and verify PullRequestInfo array
}
