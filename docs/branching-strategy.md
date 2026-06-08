# Branching Strategy

## Overview

Feature-wise branches from `main`, each implementing one atomic, reviewable unit of work. Merged back via PR when complete.

```
main ─── feat-a ──► PR ──► main ─── feat-b ──► PR ──► main ─── ...
```

## Branch Naming

```
feature/<domain>-<verb>    — e.g. feature/tests-context, feature/gitlab-issues
```

No personal branches, no `fix/` or `chore/` prefixes — every branch is a feature delivery.

## Commit Convention

Each branch ends with a single merge commit to `main`. Individual commits within a branch follow conventional commits:

```
feat: add GitLab issue list support
fix: handle 401 responses correctly
docs: update provider API mappings
refactor: extract token resolution to auth module
test: add remote URL parsing tests
```

## Branch Catalog

### Phase 0 — Foundation (v0.1)

| Branch | Description | Dependencies |
|--------|-------------|-------------|
| `main` | Initial commit: all current source, tests, docs, build system | — |
| `feature/tests-context` | Fill in `context_test.zig` — URL parsing for SSH/HTTPS/self-hosted | `main` |
| `feature/tests-cli` | Fill in `cli_test.zig` — arg parsing for all command variants | `main` |
| `feature/tests-github` | Fill in `github_test.zig` — mock JSON response parsing | `main` |
| `feature/config-read` | Implement `config.schema.read()` | `main` |
| `feature/config-write` | Implement `config.schema.write()` | `feature/config-read` |

### Phase 1 — GitLab (v0.2)

| Branch | Description | Dependencies |
|--------|-------------|-------------|
| `feature/gitlab-repos` | GitLab `repo_view` vtable implementation | `main` |
| `feature/gitlab-issues` | GitLab issue list/view via API v4 | `feature/gitlab-repos` |
| `feature/gitlab-prs` | GitLab PR list/view mapped to merge requests | `feature/gitlab-issues` |

### Phase 2 — Create Operations (v0.3)

| Branch | Description | Dependencies |
|--------|-------------|-------------|
| `feature/issue-create-close` | `issue create` / `issue close` commands | `main` |
| `feature/pr-create-merge` | `pr create` / `pr merge` commands | `feature/issue-create-close` |

### Phase 3 — Releases + Gitea (v0.4)

| Branch | Description | Dependencies |
|--------|-------------|-------------|
| `feature/release-list-view` | `release list` / `release view` | `main` |
| `feature/release-create` | `release create` | `feature/release-list-view` |
| `feature/gitea-provider` | Full Gitea/Forgejo implementation | `feature/release-create` |

### Phase 4 — CI/CD Runs (v0.5)

| Branch | Description | Dependencies |
|--------|-------------|-------------|
| `feature/run-list-view` | `run list` / `run view` | `main` |
| `feature/run-rerun` | `run rerun` | `feature/run-list-view` |

### Phase 5 — Auth & Polish (v1.0)

| Branch | Description | Dependencies |
|--------|-------------|-------------|
| `feature/keychain-macos` | macOS `security` CLI integration | `main` |
| `feature/keychain-linux` | Linux `secret-tool` integration | `feature/keychain-macos` |
| `feature/oauth-device-flow` | GitHub OAuth device flow | `main` |
| `feature/auth-commands` | `auth login/logout/list/status` CLI | `feature/keychain-linux`, `feature/oauth-device-flow` |
| `feature/doctor-command` | `gctl doctor` diagnostics | `main` |
| `feature/shell-completions` | bash/zsh/fish completion generation | `main` |
| `feature/json-output` | `--json` flag for all commands | `main` |

## Workflow

```sh
# Start from main
git checkout main
git pull

# Create feature branch
git checkout -b feature/<name>

# Work, commit, push
zig build && zig build test
git add -A && git commit -m "feat: ..."

# Open PR, merge, delete branch
gh pr create
gh pr merge --squash
git branch -d feature/<name>
```
