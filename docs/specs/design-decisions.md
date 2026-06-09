# Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | **Zig stdlib only** | Fast builds, tiny binary (~2-3 MB static), zero dependency churn. |
| 2 | **JSON config, not YAML** | `std.json` is built-in. No mature Zig YAML library exists. |
| 3 | **Env var tokens first** | Prove the CLI experience before building OAuth/keychain. Avoids classic auth trap. |
| 4 | **Capability vtables** | Each provider sets nullable vtables per feature area. Avoids lowest-common-denominator. Start with 3 vtables (repos, issues, prs). Add others only when users prove need. |
| 5 | **`gctl doctor` replaces `gctl context`** | Single diagnostic command with two modes: `--quick` for local-only checks (the old `context` use case), no flag for full API verification. Eliminates overlap between separate "context" and "doctor" commands. |
| 6 | **`gctl status` is repo pulse, not a one-liner** | `status` makes API calls and shows open issues, PRs, latest activity. Distinct from `doctor` (health) and `doctor --quick` (local config). |
| 7 | **`gctl api` as escape hatch** | Direct API access prevents abstraction leaks from blocking users. |
| 8 | **Multi-context from v0.3** | All git remotes are parsed, not just the first. Unlocks cross-provider operations (mirror, move, export). Single-ctx implied by default. |
| 9 | **Flat accounts array** | Multi-account-per-provider from day 1. Simpler than nested provider config. |
| 10 | **Build what's needed** | All features land in main as ready. No version gating — ship when implemented. |
| 11 | **Bitbucket deferred** | CLI-heavy developer usage too small to justify API complexity. |
| 12 | **Shell out for git & keychain** | `git` CLI, `security` (macOS) / `secret-tool` (Linux). No libgit2 or pure-Zig keychain libraries. Premature to bind to C libs. |
| 13 | **Flags anywhere** | `--provider` and other flags work before or after the command for maximum UX flexibility. |
| 14 | **Generic TOKEN fallback** | Custom/unknown providers use a `TOKEN` env var as a universal fallback. |
| 15 | **Cross-provider operations before releases/runs** | `gctl copy`/`diff` across providers is the marquee feature. Releases, runs, and pipelines only if users ask. |
| 16 | **No premature vtables** | Don't add releases, pipelines, or other capability vtables until a user workflow demands them. `gctl api` is the escape hatch. |
| 17 | **No separate ResourceAdapter** | Copy = `view` + `create` + JSON serialization. The existing vtables already provide read/write. Extra export/import vtables are redundant. |
| 18 | **Explicit direction, no auto-detect** | `copy` and `diff` always take an explicit target remote. No smart direction inference — surprises are worse than extra typing. |
| 19 | **REST-style resource paths** | `issues/14` not `issue 14`. Matches how the underlying APIs address resources. Type is a path segment, not a CLI verb — adding a new type requires no CLI changes. |
| 20 | **export/import as Unix filters** | stdout/stdin JSON interchange enables pipe composition (`export | import`, `export > file`, `cat file | import`). Not just an internal mechanism. |

## Status

All work targets a single `v1.0.0` release. Features land in `main` as they're implemented. No intermediate version milestones.
