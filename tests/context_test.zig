const std = @import("std");
const context = @import("context");

test "parseRemote: github HTTPS" {
    // TODO: Test parseRemote with "https://github.com/owner/repo.git"
    _ = context;
}

test "parseRemote: github SSH" {
    // TODO: Test parseRemote with "git@github.com:owner/repo.git"
}

test "parseRemote: gitlab self-hosted" {
    // TODO: Test parseRemote with "git@gitlab.company.com:team/project.git"
}

test "parseRemote: unknown URL" {
    // TODO: Test parseRemote with an unrecognized URL returns null
}

test "resolve: auto-detection from git remote" {
    // TODO: Mock git remote -v and test context resolution
}
