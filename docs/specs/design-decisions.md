# Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | **Zig stdlib only** | Fast builds, tiny binary (~2-3 MB static), zero dependency churn. |
| 2 | **JSON config, not YAML** | `std.json` is built-in. No mature Zig YAML library exists. |
| 3 | **Env var tokens first** | Prove the CLI experience before building OAuth/keychain. Avoids classic auth trap. |
| 4 | **Capability vtables** | Each provider sets nullable vtables per feature area. Avoids lowest-common-denominator. Start with 3 vtables (repos, issues, prs). Add others only when users prove need. |
| 5 | **`gctl context` as cornerstone** | Transparent context debugging prevents support burden. |
| 6 | **`gctl api` as escape hatch** | Direct API access prevents abstraction leaks from blocking users. |
| 7 | **Multi-context from v0.3** | All git remotes are parsed, not just the first. Unlocks cross-provider operations (mirror, move, export). Single-ctx implied by default. |
| 8 | **Flat accounts array** | Multi-account-per-provider from day 1. Simpler than nested provider config. |
| 9 | **Compact roadmap** | Ship v0.1→v0.4 sequentially. Defer everything to v1.0+ until users prove need. |
| 10 | **Bitbucket deferred** | CLI-heavy developer usage too small to justify API complexity. |
| 11 | **Shell out for git & keychain** | `git` CLI, `security` (macOS) / `secret-tool` (Linux). No libgit2 or pure-Zig keychain libraries. Premature to bind to C libs. |
| 12 | **Flags anywhere** | `--provider` and other flags work before or after the command for maximum UX flexibility. |
| 13 | **Generic TOKEN fallback** | Custom/unknown providers use a `TOKEN` env var as a universal fallback. |
| 14 | **Mirror before releases/runs** | `gctl mirror` (continuous sync) is the marquee feature. Releases, runs, and pipelines only if users ask. |
| 15 | **No premature vtables** | Don't add releases, pipelines, or other capability vtables until a user workflow demands them. `gctl api` is the escape hatch. |

## Roadmap

| Version | Scope | Status |
|---------|-------|--------|
| v0.1 | GitHub, context, env tokens, custom provider, tests, config | ✅ Current |
| v0.2 | GitLab support (repos, issues, merge requests) | In progress |
| v0.3 | Extended repo ops (create/delete/archive), labels (set_all), multi-context, issue/pr create/close/merge | Planned |
| v0.4 | `gctl mirror` (continuous sync between repos/providers) | Planned |
| v1.0 | Persistent auth (keychain + OAuth), auth commands | Planned |
