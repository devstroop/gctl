# gitctl

[![CI](https://github.com/devstroop/gitctl/actions/workflows/ci.yml/badge.svg)](https://github.com/devstroop/gitctl/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Cross-forge Git operations — one CLI.**

`cd anywhere && gitctl status` — knows your provider, owner, and repo from git remotes. No config. No flags. No friction.

<br>

---

## Why

You work across GitHub and GitLab every day. Personal projects on GitHub. Company code on GitLab. Self-hosted forges for internal tools.

Each platform has its own CLI, its own auth, its own syntax. `gh`, `glab` — two tools, two configs, two mental models.

`gitctl` replaces that with one command.

---

## What It Does

```
cd ~/projects/api          # github.com remote
gitctl issue list            # → GitHub issues

cd ~/work/backend          # gitlab.company.com remote
gitctl pr list               # → GitLab merge requests

gitctl repo view             # details from whatever provider
gitctl network               # debug what was detected

gitctl api GET /user         # raw API escape hatch
```

No `--provider` flag. The tool reads your git remote and figures it out.

---

## Quick Start

### Install

```sh
git clone https://github.com/devstroop/gitctl
cd gitctl
zig build -Doptimize=ReleaseSafe
cp zig-out/bin/gitctl /usr/local/bin/
```

### Authenticate

```sh
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
export GITLAB_TOKEN=glpat-xxxxxxxxxxxx
```

### Use

```sh
cd any-git-repo
gitctl network         # see all remotes detected
gitctl doctor          # system diagnostics
gitctl issue list      # list open issues
gitctl pr view 42      # view a PR / merge request
gitctl run list        # list CI/CD runs
gitctl --json          # machine-readable output
```

---

## Commands

| Command | Description |
|---------|-------------|
| `gitctl doctor [--quick]` | System diagnostics |
| `gitctl network [--all]` | Show all remotes with provider, owner, repo |
| `gitctl status` | High-level repo summary |
| `gitctl repo view [owner/repo]` | View repository details |
| `gitctl repo create <name>` | Create a repository |
| `gitctl repo delete <name>` | Delete a repository |
| `gitctl repo archive <name>` | Archive a repository |
| `gitctl label set_all <labels>` | Replace all repo labels |
| `gitctl issue create <title>` | Create an issue |
| `gitctl issue close <n>` | Close an issue |
| `gitctl issue list` | List open issues |
| `gitctl issue view <n>` | View an issue |
| `gitctl pr create <title>` | Create a pull/merge request |
| `gitctl pr merge <n>` | Merge a pull/merge request |
| `gitctl pr list` | List open pull/merge requests |
| `gitctl pr view <n>` | View a pull/merge request |
| `gitctl release list` | List releases |
| `gitctl release view <tag>` | View a release |
| `gitctl release create <tag>` | Create a release |
| `gitctl run list` | List CI/CD runs |
| `gitctl run view <id>` | View a CI/CD run |
| `gitctl run rerun <id>` | Rerun a CI/CD run |
| `gitctl export <path>` | Export resource as JSON |
| `gitctl import <path>` | Create resource from JSON |
| `gitctl copy <src> <tgt>` | Copy resource across remotes |
| `gitctl diff <src> <tgt>` | Compare resource across remotes |
| `gitctl api <method> <path>` | Direct API call |
| `gitctl auth login <provider>` | Store a token |
| `gitctl auth logout <provider>` | Remove stored token |
| `gitctl auth list` | Show configured accounts |
| `gitctl auth status` | Show auth context |
| `gitctl completion bash\|zsh\|fish` | Generate shell completions |

---

## Supported Providers

| Provider | Status | Auth |
|----------|--------|------|
| GitHub | ✅ | Token (env var / keychain) |
| GitLab (incl. self-hosted) | ✅ | Token (env var / keychain) |
| Gitea / Forgejo | ✅ | Token (env var / keychain) |
| Custom | ✅ | Token (env var / keychain) |
| Bitbucket | 🔲 | Planned |

---

## How It Works

1. **Reads your git remote** — `git remote -v` → `github.com` → GitHub provider
2. **Finds your token** — Checks `GITHUB_TOKEN` / `GITLAB_TOKEN` / `GITEA_TOKEN` env vars, then system keychain
3. **Calls the API** — Provider maps `gitctl` commands to REST API calls
4. **Shows the result** — Formatted table or key-value output (use `--json` for machine-readable)

No magic. Just git remotes, HTTP, and JSON.

---

## Philosophy

- **Git-first**: The git remote is the source of truth. Not config. Not flags.
- **Thin vtables**: Start with what users need. Add capabilities when proven.
- **One binary**: Single static executable. No runtime, no dependencies.
- **gitctl api**: The escape hatch for anything not wrapped yet.

---

## Building from Source

Requires [Zig](https://ziglang.org/) 0.15 or later.

```sh
git clone https://github.com/devstroop/gitctl
cd gitctl
zig build
zig build test
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the branching workflow, build process, and code conventions.

---

## License

MIT
