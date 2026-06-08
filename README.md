# gctl

**One CLI for every Git forge.**

`cd anywhere && gctl status` — and it just knows.

---

## Why

You work across GitHub, GitLab, and Forgejo every day. Personal projects on GitHub. Company code on GitLab. Self-hosted Forgejo for internal tools.

Each platform demands its own CLI, its own auth, its own syntax. `gh`, `glab`, `tea` — three tools, three configs, three mental models.

`gctl` replaces that with one command.

---

## What It Does

```
# Context is automatic
cd ~/projects/api          # github.com remote
gctl issue list            # → shows GitHub issues

cd ~/work/backend          # gitlab.company.com remote
gctl pr list               # → shows GitLab merge requests

# Works across providers
gctl repo view             # → shows details from whatever provider you're in

# Escape hatch when you need raw API access
gctl api GET /user
gctl api gitlab GET /projects
```

No `--provider` flag needed. The tool reads your git remote and figures it out.

---

## Quick Start

### Install

```sh
# macOS
brew install gctl

# From source
git clone https://github.com/gctl/gctl
cd gctl
zig build -Doptimize=ReleaseSafe
cp zig-out/bin/gctl /usr/local/bin/
```

### Authenticate

```sh
# GitHub
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
gctl auth login github

# GitLab
export GITLAB_TOKEN=glpat-xxxxxxxxxxxx
gctl auth login gitlab
```

### Use

```sh
cd any-git-repo
gctl context         # see what it detected
gctl issue list      # list open issues
gctl pr view 42      # view a pull request
gctl api GET /user   # raw API call
```

---

## Commands

| Command | Description |
|---------|-------------|
| `gctl context` | Show detected provider, account, owner, repo |
| `gctl status` | High-level repo summary |
| `gctl repo view` | View repository details |
| `gctl issue list` | List open issues |
| `gctl issue view <n>` | View an issue |
| `gctl issue create` | Create an issue |
| `gctl issue close <n>` | Close an issue |
| `gctl pr list` | List open pull/merge requests |
| `gctl pr view <n>` | View a pull/merge request |
| `gctl pr create` | Create a pull/merge request |
| `gctl pr merge <n>` | Merge a pull/merge request |
| `gctl run list` | List CI/CD runs |
| `gctl run view <n>` | View a CI/CD run |
| `gctl release list` | List releases |
| `gctl api <method> <path>` | Direct API call |
| `gctl auth login <p>` | Authenticate with a provider |
| `gctl auth list` | Show authenticated accounts |
| `gctl doctor` | Diagnose setup issues |

---

## Supported Providers

| Provider | Status | Auth |
|----------|--------|------|
| GitHub | ✅ | Token, OAuth |
| GitLab (incl. self-hosted) | ✅ | Token, PAT |
| Gitea / Forgejo | ✅ | Token |
| Bitbucket | ❌ | Not planned |

---

## How It Works

1. **Reads your git remote** — `git remote -v` → `github.com` → GitHub provider
2. **Finds your token** — Checks `GITHUB_TOKEN` env var, then OS keychain, then config
3. **Calls the API** — Provider maps `gctl` commands to REST API calls
4. **Shows the result** — Formatted table or key-value output

No magic. Just git remotes, HTTP, and JSON.

---

## Config

`~/.gctl/config.json`:

```json
{
  "accounts": [
    { "name": "personal", "provider": "github" },
    { "name": "work", "provider": "gitlab", "url": "https://gitlab.company.com" }
  ],
  "defaults": { "provider": "auto" }
}
```

---

## Philosophy

- **Git-first**: The git remote is the source of truth. Not config. Not flags.
- **Minimal surface**: If it's not common across providers, it's behind `gctl api`.
- **One binary**: `gctl` is a single static executable. No runtime, no dependencies.
- **Learn in minutes**: 8 core commands cover 90% of daily forge interaction.

---

## Building from Source

Requires [Zig](https://ziglang.org/) 0.15 or later.

```sh
git clone https://github.com/gctl/gctl
cd gctl
zig build
zig build test
```

---

## License

MIT
