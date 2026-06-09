# gitctl — Specification Index

> Cross-forge Git operations — one CLI.
> Zig 0.15+ · stdlib only · single static binary

## Overview

`gitctl` is a provider-agnostic CLI for Git hosting platforms. Unlike `gh` (GitHub) or `glab` (GitLab), it unifies a small, consistent set of workflows across GitHub, GitLab, and custom providers.

The core strength is **context detection**: `cd anywhere && gitctl status` instantly knows the provider, account, owner, and repo. No flags, no config, no ceremony.

---

## Specification Documents

| Document | Description |
|----------|-------------|
| [Architecture](./architecture.md) | Capability-driven provider model, resolution chain, token resolution, directory structure |
| [Commands](./commands.md) | Complete command reference |
| [Providers](./providers.md) | Provider-specific API endpoint mappings |
| [Config](./config.md) | Config file schema and account management |
| [Error Handling](./error-handling.md) | Error taxonomy, user-facing messages |
| [Design Decisions](./design-decisions.md) | Key architectural decisions and rationale |
