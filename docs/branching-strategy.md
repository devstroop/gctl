# Branching Strategy

## Model

**GitHub Flow** — single `main` branch is always deployable. All work happens on short-lived branches that branch from `main` and merge back via PR. No `develop`, no `release/*`, no long-running feature branches.

```
main ──► <type>/desc ──► PR ──► main ──► <type>/desc ──► PR ──► main ──► ...
```

Release branches and hotfix flow will be added when v1.0 ships and requires patch maintenance.

## Branch Naming

```
<type>/<short-description>
```

Branch type matches the primary conventional commit type of the work:

| Type | When |
|------|------|
| `feat/` | New feature or capability |
| `fix/` | Bug fix |
| `docs/` | Documentation-only changes |
| `refactor/` | Code restructuring with no behaviour change |
| `test/` | Adding or fixing tests |
| `chore/` | Build, config, tooling, dependencies |
| `ci/` | CI/CD pipeline changes |
| `perf/` | Performance improvement |

Existing `feature/*` branches are kept as-is on the remote. New branches follow this convention.

## Commit Convention

Each branch ends with a single merge commit to `main`. Individual commits within a branch follow conventional commits:

```
feat: add GitLab issue list support
fix: handle 401 responses correctly
docs: update provider API mappings
refactor: extract token resolution to auth module
test: add remote URL parsing tests
```

The branch type should match the primary commit type in the branch.

## Branch Catalog

### Phase 0 — Foundation (v0.1)

| Branch | Type | Description | Status |
|--------|------|-------------|--------|
| `main` | — | Initial commit: all current source, tests, docs, build system | ✅ Done |
| `feature/tests-context` | test | `context_test.zig` — URL parsing for SSH/HTTPS/self-hosted | ✅ Done |
| `feature/tests-cli` | test | `cli_test.zig` — arg parsing for all command variants | ✅ Done |
| `feature/tests-github` | test | `github_test.zig` — mock JSON response parsing | ✅ Done |
| `feature/config-read` | feat | Implement `config.schema.read()` | ✅ Done |
| `feature/config-write` | feat | Implement `config.schema.write()` | ✅ Done |

### Phase 1 — GitLab (v0.2)

| Branch | Type | Description | Status |
|--------|------|-------------|--------|
| `feature/gitlab-repos` | feat | GitLab `repo_view` via `/projects/{id}`. URL encoding. Register in provider registry | ✅ Done |
| `feature/gitlab-issues` | feat | GitLab issue list/view via `/projects/{id}/issues` | ✅ Done |
| `feature/gitlab-prs` | feat | GitLab merge request list/view via `/projects/{id}/merge_requests` | ✅ Done |

### Phase 2 — Extended Ops (v0.3)

| Branch (future) | Type | Description | Status |
|-----------------|------|-------------|--------|
| `feature/repo-create-delete-archive` | feat | Extend `RepoVtable` with `create()`, `delete()`, `archive()` | ✅ Done |
| `feature/label-set-all` | feat | Add `LabelVtable` with `set_all()`. CLI: `label set_all` | ✅ Done |
| `feat/multi-context` | feat | `resolve()` → `[]ResolvedContext`. Parse all remotes. `gctl context --all`. Thread context slice through dispatch | ⏳ Planned |
| `feat/issue-create-close` | feat | `issue create` / `issue close`. Add create/close to `IssueVtable` | ⏳ Planned |
| `feat/pr-create-merge` | feat | `pr create` / `pr merge`. Add create/merge to `PRVtable` | ⏳ Planned |

### Phase 3 — Mirror (v0.4)

| Branch | Type | Description | Status |
|--------|------|-------------|--------|
| `feat/mirror-engine` | feat | Core sync: enumerate issues/PRs from source, upsert to target. Mapping layer between provider types | ⏳ Planned |
| `feat/mirror-cli` | feat | CLI: `gctl mirror list`, `gctl mirror setup`, `gctl mirror run`. Config in `~/.gctl/mirrors.json` | ⏳ Planned |
| `feat/mirror-git-sync` | feat | Git operation layer: `git push --mirror` via CLI, divergent history handling | ⏳ Planned |

### Phase 4 — Auth (v1.0)

| Branch | Type | Description | Status |
|--------|------|-------------|--------|
| `feat/keychain-macos` | feat | macOS `security` CLI integration for token storage | ⏳ Planned |
| `feat/keychain-linux` | feat | Linux `secret-tool` integration | ⏳ Planned |
| `feat/oauth-device-flow` | feat | GitHub OAuth device flow (device_code, polling, token store) | ⏳ Planned |
| `feat/auth-commands` | feat | `auth login/logout/list/status` CLI commands | ⏳ Planned |

## Hotfix / Release (deferred)

No release branches or hotfix flow before v1.0. When the project ships a stable release:

- **Release branches** (`release/v1.x`) will be cut from `main` for patch backports.
- **Hotfix branches** (`hotfix/<description>`) will branch from the release tag, fix forward, and merge to both the release branch and `main`.

Until then, all changes flow through `main`.

## Scrapped (not planned)

These were proposed but removed as premature — no user workflow proves them yet:

| Proposed | Type | Reason |
|----------|------|--------|
| `feature/release-*` / `feat/release-*` | feat | Release list/view/create — no user demand |
| `feature/run-*` / `feat/run-*` | feat | CI/CD run list/view/rerun — no user demand |
| `feat/doctor-command` | feat | Diagnostics — premature polish |
| `feat/shell-completions` | feat | Tab completion — premature polish |
| `feat/json-output` | feat | `--json` flag — premature formatting concern |
| `feat/gitea-provider` | feat | Gitea/Forgejo — no user demand (can be revived) |

## Workflow

```sh
# Start from main
git checkout main
git pull

# Create branch with type prefix
git checkout -b feat/add-something    # or fix/, docs/, chore/, etc.

# Work, commit, push
zig build && zig build test
git add -A && git commit -m "feat: add something"   # type matches branch prefix

# Open PR, merge, delete branch
gh pr create
gh pr merge --squash
git branch -d feat/add-something
```
