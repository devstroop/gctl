# gctl

[![CI](https://github.com/devstroop/gctl/actions/workflows/ci.yml/badge.svg)](https://github.com/devstroop/gctl/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Cross-forge Git operations — one CLI.**

`cd anywhere && gctl status` — knows your provider, owner, and repo from git remotes. No config. No flags. No friction.

<br>

---

## Why

You work across GitHub and GitLab every day. Personal projects on GitHub. Company code on GitLab. Self-hosted forges for internal tools.

Each platform has its own CLI, its own auth, its own syntax. `gh`, `glab` — two tools, two configs, two mental models.

`gctl` replaces that with one command.

---

## What It Does

```
cd ~/projects/api          # github.com remote
gctl issue list            # → GitHub issues

cd ~/work/backend          # gitlab.company.com remote
gctl pr list               # → GitLab merge requests

gctl repo view             # details from whatever provider
gctl context               # debug what was detected

gctl api GET /user         # raw API escape hatch
```

No `--provider` flag. The tool reads your git remote and figures it out.

---

## Quick Start

### Install

```sh
git clone https://github.com/devstroop/gctl
cd gctl
zig build -Doptimize=ReleaseSafe
cp zig-out/bin/gctl /usr/local/bin/
```

### Authenticate

```sh
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
export GITLAB_TOKEN=glpat-xxxxxxxxxxxx
```

### Use

```sh
cd any-git-repo
gctl context         # see what it detected
gctl issue list      # list open issues
gctl pr view 42      # view a PR / merge request
```

---

## Commands

| Command | Description |
|---------|-------------|
| `gctl context [--all]` | Show detected provider, owner, repo, remote |
| `gctl status` | High-level repo summary |
| `gctl repo view [owner/repo]` | View repository details |
| `gctl repo create <name>` | Create a repository |
| `gctl repo delete <name>` | Delete a repository |
| `gctl repo archive <name>` | Archive a repository |
| `gctl label set_all <labels>` | Replace all repo labels |
| `gctl issue create <title>` | Create an issue |
| `gctl issue close <n>` | Close an issue |
| `gctl issue list` | List open issues |
| `gctl issue view <n>` | View an issue |
| `gctl pr create <title>` | Create a pull/merge request |
| `gctl pr merge <n>` | Merge a pull/merge request |
| `gctl pr list` | List open pull/merge requests |
| `gctl pr view <n>` | View a pull/merge request |
| `gctl api <method> <path>` | Direct API call |

---

## Supported Providers

| Provider | Status | Auth |
|----------|--------|------|
| GitHub | ✅ | Token (env var) |
| GitLab (incl. self-hosted) | ✅ | Token (env var) |
| Gitea / Forgejo | 🔲 | Planned |
| Custom | ✅ | Token (env var) |
| Bitbucket | 🔲 | Planned |

---

## How It Works

1. **Reads your git remote** — `git remote -v` → `github.com` → GitHub provider
2. **Finds your token** — Checks `GITHUB_TOKEN` / `GITLAB_TOKEN` env vars
3. **Calls the API** — Provider maps `gctl` commands to REST API calls
4. **Shows the result** — Formatted table or key-value output

No magic. Just git remotes, HTTP, and JSON.

---

## Philosophy

- **Git-first**: The git remote is the source of truth. Not config. Not flags.
- **Thin vtables**: Start with what users need. Add capabilities when proven.
- **One binary**: Single static executable. No runtime, no dependencies.
- **gctl api**: The escape hatch for anything not wrapped yet.

---

## Building from Source

Requires [Zig](https://ziglang.org/) 0.15 or later.

```sh
git clone https://github.com/devstroop/gctl
cd gctl
zig build
zig build test
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the branching workflow, build process, and code conventions.

---

## License

MIT
