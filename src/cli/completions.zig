const std = @import("std");

const shells = [_][]const u8{ "bash", "zsh", "fish" };

pub fn completeBash(writer: anytype) !void {
    try writer.interface.writeAll(
        \\_gitctl_completions() {
        \\  local cur prev words cword
        \\  _init_completion || return
        \\
        \\  local commands="doctor network status repo label issue pr api export import copy diff auth"
        \\  local subcommands="view create delete archive set_all list close merge"
        \\  local flags="--provider -p --provider-url -u --account -a --description --private --base --json -j --help -h --all --quick"
        \\
        \\  if [[ $cword -eq 1 ]]; then
        \\    COMPREPLY=($(compgen -W "$commands" -- "$cur"))
        \\    return
        \\  fi
        \\
        \\  case "${words[1]}" in
        \\    repo)
        \\      if [[ $cword -eq 2 ]]; then
        \\        COMPREPLY=($(compgen -W "view create delete archive" -- "$cur"))
        \\      else
        \\        COMPREPLY=($(compgen -W "$flags" -- "$cur"))
        \\      fi
        \\      ;;
        \\    issue)
        \\      if [[ $cword -eq 2 ]]; then
        \\        COMPREPLY=($(compgen -W "list view create close" -- "$cur"))
        \\      else
        \\        COMPREPLY=($(compgen -W "$flags" -- "$cur"))
        \\      fi
        \\      ;;
        \\    pr)
        \\      if [[ $cword -eq 2 ]]; then
        \\        COMPREPLY=($(compgen -W "list view create merge" -- "$cur"))
        \\      else
        \\        COMPREPLY=($(compgen -W "$flags" -- "$cur"))
        \\      fi
        \\      ;;
        \\    label)
        \\      if [[ $cword -eq 2 ]]; then
        \\        COMPREPLY=($(compgen -W "set_all" -- "$cur"))
        \\      else
        \\        COMPREPLY=($(compgen -W "$flags" -- "$cur"))
        \\      fi
        \\      ;;
        \\    auth)
        \\      if [[ $cword -eq 2 ]]; then
        \\        COMPREPLY=($(compgen -W "login logout list status" -- "$cur"))
        \\      else
        \\        COMPREPLY=($(compgen -W "$flags" -- "$cur"))
        \\      fi
        \\      ;;
        \\    *)
        \\      COMPREPLY=($(compgen -W "$flags" -- "$cur"))
        \\      ;;
        \\  esac
        \\} &&
        \\complete -F _gitctl_completions gitctl
        \\
    );
}

pub fn completeZsh(writer: anytype) !void {
    try writer.interface.writeAll(
        \\#compdef gitctl
        \\
        \\_gitctl() {
        \\  local -a commands
        \\  commands=(
        \\    'doctor:System diagnostics'
        \\    'network:Show all remotes'
        \\    'status:Repo pulse'
        \\    'repo:Repository operations'
        \\    'label:Label operations'
        \\    'issue:Issue operations'
        \\    'pr:Pull/merge request operations'
        \\    'api:Direct API call'
        \\    'export:Export resource as JSON'
        \\    'import:Import resource from JSON'
        \\    'copy:Copy resource across remotes'
        \\    'diff:Compare resource across remotes'
        \\    'auth:Authentication'
        \\  )
        \\
        \\  local -a repo_ops=(view create delete archive)
        \\  local -a issue_ops=(list view create close)
        \\  local -a pr_ops=(list view create merge)
        \\  local -a label_ops=(set_all)
        \\  local -a auth_ops=(login logout list status)
        \\  local -a global_flags=(
        \\    '--provider[Override provider]:provider:(github gitlab gitea)'
        \\    '-p[Override provider]:provider:(github gitlab gitea)'
        \\    '--provider-url[Base URL for custom provider]:url'
        \\    '-u[Base URL for custom provider]:url'
        \\    '--account[Override account]:account'
        \\    '-a[Override account]:account'
        \\    '--description[Repo description]:text'
        \\    '--private[Make repo private]'
        \\    '--base[Target branch]:branch'
        \\    '--json[Output as JSON]'
        \\    '-j[Output as JSON]'
        \\    '--help[Show help]'
        \\    '-h[Show help]'
        \\    '--all[Show all]'
        \\    '--quick[Skip token checks]'
        \\  )
        \\
        \\  if [[ $CURRENT -eq 2 ]]; then
        \\    _describe 'command' commands
        \\    _arguments $global_flags
        \\    return
        \\  fi
        \\
        \\  case "$words[2]" in
        \\    repo)  _describe 'subcommand' repo_ops; _arguments $global_flags ;;
        \\    issue) _describe 'subcommand' issue_ops; _arguments $global_flags ;;
        \\    pr)    _describe 'subcommand' pr_ops; _arguments $global_flags ;;
        \\    label) _describe 'subcommand' label_ops; _arguments $global_flags ;;
        \\    auth)  _describe 'subcommand' auth_ops; _arguments $global_flags ;;
        \\    *)     _arguments $global_flags ;;
        \\  esac
        \\}
        \\
        \\_gitctl
        \\
    );
}

pub fn completeFish(writer: anytype) !void {
    try writer.interface.writeAll(
        \\complete -c gitctl -f
        \\
        \\# Commands
        \\complete -c gitctl -n "not __fish_seen_subcommand_from doctor network status repo label issue pr api export import copy diff auth" -a doctor -d "System diagnostics"
        \\complete -c gitctl -n "not __fish_seen_subcommand_from doctor network status repo label issue pr api export import copy diff auth" -a network -d "Show all remotes"
        \\complete -c gitctl -n "not __fish_seen_subcommand_from doctor network status repo label issue pr api export import copy diff auth" -a status -d "Repo pulse"
        \\complete -c gitctl -n "not __fish_seen_subcommand_from doctor network status repo label issue pr api export import copy diff auth" -a repo -d "Repository operations"
        \\complete -c gitctl -n "not __fish_seen_subcommand_from doctor network status repo label issue pr api export import copy diff auth" -a label -d "Label operations"
        \\complete -c gitctl -n "not __fish_seen_subcommand_from doctor network status repo label issue pr api export import copy diff auth" -a issue -d "Issue operations"
        \\complete -c gitctl -n "not __fish_seen_subcommand_from doctor network status repo label issue pr api export import copy diff auth" -a pr -d "Pull/merge request operations"
        \\complete -c gitctl -n "not __fish_seen_subcommand_from doctor network status repo label issue pr api export import copy diff auth" -a api -d "Direct API call"
        \\complete -c gitctl -n "not __fish_seen_subcommand_from doctor network status repo label issue pr api export import copy diff auth" -a export -d "Export resource as JSON"
        \\complete -c gitctl -n "not __fish_seen_subcommand_from doctor network status repo label issue pr api export import copy diff auth" -a import -d "Import resource from JSON"
        \\complete -c gitctl -n "not __fish_seen_subcommand_from doctor network status repo label issue pr api export import copy diff auth" -a copy -d "Copy resource across remotes"
        \\complete -c gitctl -n "not __fish_seen_subcommand_from doctor network status repo label issue pr api export import copy diff auth" -a diff -d "Compare resource across remotes"
        \\complete -c gitctl -n "not __fish_seen_subcommand_from doctor network status repo label issue pr api export import copy diff auth" -a auth -d "Authentication"
        \\
        \\# Repo subcommands
        \\complete -c gitctl -n "__fish_seen_subcommand_from repo" -a "view" -d "View repository"
        \\complete -c gitctl -n "__fish_seen_subcommand_from repo" -a "create" -d "Create repository"
        \\complete -c gitctl -n "__fish_seen_subcommand_from repo" -a "delete" -d "Delete repository"
        \\complete -c gitctl -n "__fish_seen_subcommand_from repo" -a "archive" -d "Archive/unarchive repository"
        \\
        \\# Issue subcommands
        \\complete -c gitctl -n "__fish_seen_subcommand_from issue" -a "list" -d "List issues"
        \\complete -c gitctl -n "__fish_seen_subcommand_from issue" -a "view" -d "View issue"
        \\complete -c gitctl -n "__fish_seen_subcommand_from issue" -a "create" -d "Create issue"
        \\complete -c gitctl -n "__fish_seen_subcommand_from issue" -a "close" -d "Close issue"
        \\
        \\# PR subcommands
        \\complete -c gitctl -n "__fish_seen_subcommand_from pr" -a "list" -d "List pull/merge requests"
        \\complete -c gitctl -n "__fish_seen_subcommand_from pr" -a "view" -d "View pull/merge request"
        \\complete -c gitctl -n "__fish_seen_subcommand_from pr" -a "create" -d "Create pull/merge request"
        \\complete -c gitctl -n "__fish_seen_subcommand_from pr" -a "merge" -d "Merge pull/merge request"
        \\
        \\# Label subcommands
        \\complete -c gitctl -n "__fish_seen_subcommand_from label" -a "set_all" -d "Replace all repo labels"
        \\
        \\# Auth subcommands
        \\complete -c gitctl -n "__fish_seen_subcommand_from auth" -a "login" -d "Store a token"
        \\complete -c gitctl -n "__fish_seen_subcommand_from auth" -a "logout" -d "Remove stored token"
        \\complete -c gitctl -n "__fish_seen_subcommand_from auth" -a "list" -d "Show configured accounts"
        \\complete -c gitctl -n "__fish_seen_subcommand_from auth" -a "status" -d "Show auth context"
        \\
        \\# Global flags
        \\complete -c gitctl -l provider -s p -r -d "Override provider"
        \\complete -c gitctl -l provider-url -s u -r -d "Base URL for custom provider"
        \\complete -c gitctl -l account -s a -r -d "Override account"
        \\complete -c gitctl -l description -r -d "Repo description"
        \\complete -c gitctl -l private -d "Make repo private"
        \\complete -c gitctl -l base -r -d "Target branch"
        \\complete -c gitctl -l json -s j -d "Output as JSON"
        \\complete -c gitctl -l help -s h -d "Show help"
        \\complete -c gitctl -l all -d "Show all"
        \\complete -c gitctl -l quick -d "Skip token checks"
        \\
    );
}

pub fn printCompletions(writer: anytype, shell: []const u8) !void {
    if (std.mem.eql(u8, shell, "bash")) return completeBash(writer);
    if (std.mem.eql(u8, shell, "zsh")) return completeZsh(writer);
    if (std.mem.eql(u8, shell, "fish")) return completeFish(writer);
    return error.UnsupportedShell;
}

test {
    for (shells) |s| {
        var buf = std.ArrayList(u8).init(std.testing.allocator);
        defer buf.deinit();
        const writer = buf.writer();
        printCompletions(writer, s) catch |err| {
            if (err == error.UnsupportedShell) @panic("unexpected");
        };
        try std.testing.expect(buf.items.len > 0);
    }
}
