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

| Branch | Description | Status |
|--------|-------------|--------|
| `main` | Initial commit: all current source, tests, docs, build system | ✅ Done |
| `feature/tests-context` | Fill in `context_test.zig` — URL parsing for SSH/HTTPS/self-hosted | ✅ Done |
| `feature/tests-cli` | Fill in `cli_test.zig` — arg parsing for all command variants | ✅ Done |
| `feature/tests-github` | Fill in `github_test.zig` — mock JSON response parsing | ✅ Done |
| `feature/config-read` | Implement `config.schema.read()` | ✅ Done |
| `feature/config-write` | Implement `config.schema.write()` | ✅ Done |

### Phase 1 — GitLab (v0.2)

| Branch | Description | Dependencies |
|--------|-------------|-------------|
| `feature/gitlab-repos` | GitLab `repo_view` via `/projects/{id}`. URL encoding. Register in provider registry | `main` |
| `feature/gitlab-issues` | GitLab issue list/view via `/projects/{id}/issues` | `feature/gitlab-repos` |
| `feature/gitlab-prs` | GitLab merge request list/view via `/projects/{id}/merge_requests` | `feature/gitlab-issues` |

### Phase 2 — Extended Ops (v0.3)

| Branch | Description | Dependencies |
|--------|-------------|-------------|
| `feature/repo-create-delete-archive` | Extend `RepoVtable` with `create()`, `delete()`, `archive()` | `main` |
| `feature/label-set-all` | Add `LabelVtable` with `set_all()`. CLI: `label set_all <number> <l1,l2,...>` | `feature/repo-create-delete-archive` |
| `feature/multi-context` | `resolve()` → `[]ResolvedContext`. Parse all remotes. `gctl context --all`. Thread context slice through dispatch | `feature/label-set-all` |
| `feature/issue-create-close` | `issue create` / `issue close`. Uncomment in Command enum, add create/close to IssueVtable | `feature/multi-context` |
| `feature/pr-create-merge` | `pr create` / `pr merge`. Uncomment in Command enum, add create/merge to PRVtable | `feature/issue-create-close` |

### Phase 3 — Mirror (v0.4)

| Branch | Description | Dependencies |
|--------|-------------|-------------|
| `feature/mirror-engine` | Core sync: enumerate issues/PRs from source, upsert to target. Mapping layer between provider types | `feature/pr-create-merge` |
| `feature/mirror-cli` | CLI: `gctl mirror list`, `gctl mirror setup`, `gctl mirror run`. Config stored in `~/.gctl/mirrors.json` | `feature/mirror-engine` |
| `feature/mirror-git-sync` | Git operation layer: `git push --mirror` via CLI, divergent history handling | `feature/mirror-cli` |

### Phase 4 — Auth (v1.0)

| Branch | Description | Dependencies |
|--------|-------------|-------------|
| `feature/keychain-macos` | macOS `security` CLI integration for token storage | `main` |
| `feature/keychain-linux` | Linux `secret-tool` integration | `feature/keychain-macos` |
| `feature/oauth-device-flow` | GitHub OAuth device flow (device_code, polling, token store) | `main` |
| `feature/auth-commands` | `auth login/logout/list/status` CLI commands | `feature/keychain-linux`, `feature/oauth-device-flow` |

### Scrapped (not planned)

These were proposed but removed as premature — no user workflow proves them yet:

| Scrapped | Reason |
|----------|--------|
| `feature/release-*` | Release list/view/create — no user demand |
| `feature/run-*` | CI/CD run list/view/rerun — no user demand |
| `feature/doctor-command` | Diagnostics — premature polish |
| `feature/shell-completions` | Tab completion — premature polish |
| `feature/json-output` | `--json` flag — premature formatting concern |
| `feature/gitea-provider` | Gitea/Forgejo — no user demand (can be revived) |

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
