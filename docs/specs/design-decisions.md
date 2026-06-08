# Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | **Zig stdlib only** | Fast builds, tiny binary (~2-3 MB static), zero dependency churn. |
| 2 | **JSON config, not YAML** | `std.json` is built-in. No mature Zig YAML library exists. |
| 3 | **Env var tokens first** | Prove the CLI experience before building OAuth/keychain. Avoids classic auth trap. |
| 4 | **Capability vtables** | Each provider sets nullable vtables per feature area. Avoids lowest-common-denominator. |
| 5 | **`gctl context` as cornerstone** | Transparent context debugging prevents support burden. |
| 6 | **`gctl api` as escape hatch** | Direct API access prevents abstraction leaks from blocking users. |
| 7 | **`gctl run`, not `gctl ci`** | "Run" maps cleanly to Actions runs, Pipelines, Action runs across vendors. |
| 8 | **Flat accounts array** | Multi-account-per-provider from day 1. Simpler than nested provider config. |
| 9 | **Versioned roadmap** | Each version (v0.1–v1.0) is independently shippable and useful. |
| 10 | **Bitbucket deferred** | CLI-heavy developer usage too small to justify API complexity. |
| 11 | **Shell out for keychain** | `security` (macOS) / `secret-tool` (Linux). No pure-Zig keychain libraries. |
| 12 | **Flags anywhere** | `--provider` and other flags work before or after the command for maximum UX flexibility. |
| 13 | **Generic TOKEN fallback** | Custom/unknown providers use a `TOKEN` env var as a universal fallback. |

## Roadmap

| Version | Scope | Status |
|---------|-------|--------|
| v0.1 | GitHub, context, env tokens, custom provider | ✅ Current |
| v0.2 | GitLab support | Planned |
| v0.3 | Create operations (issue create/close, pr create/merge) | Planned |
| v0.4 | Releases + Gitea/Forgejo support | Planned |
| v0.5 | CI/CD runs | Planned |
| v1.0 | Persistent auth, doctor, completions | Planned |
