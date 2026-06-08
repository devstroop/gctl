# Contributing to gctl

## Getting Started

1. Fork the repository
2. Clone your fork
3. Build and verify: `zig build && ./zig-out/bin/gctl context`
4. Run tests: `zig build test`

## Pull Request Process

1. Create a feature branch from `main`
2. Make your changes
3. Ensure `zig build` succeeds with no errors
4. Run `zig build test` and verify all tests pass
5. Update relevant documentation in `docs/`
6. Submit a PR with a clear description

## Commit Style

Use conventional commits:

```
feat: add GitLab issue list support
fix: handle 401 responses correctly
docs: update provider API mappings
refactor: extract token resolution to auth module
test: add remote URL parsing tests
```

## Where to Help

### Good First Issues

- Write tests for `src/cli/args.zig` (see `tests/cli_test.zig` for stubs)
- Write tests for `src/context/remote.zig` remote URL parsing
- Add JSON output (`--json` flag) to `src/cli/output.zig`
- Improve error messages in `src/main.zig`

### Provider Work

- **GitLab** (`src/providers/gitlab.zig`): Implement capability vtables
- **Gitea** (`src/providers/gitea.zig`): Implement capability vtables

### Infrastructure

- Config file read/write (`src/config/mod.zig`): JSON config from `~/.gctl/config.json`
- Keychain integration (`src/auth/keychain.zig`): macOS `security` CLI wrapper
- HTTP retry logic (`src/http/client.zig`): Rate limit retry with backoff

## Architecture Rules

1. **No external dependencies.** Zig stdlib only.
2. **New providers get nullable vtables.** Set capabilities to `null` if not yet implemented.
3. **All user-facing strings go through `stderr`.** Use `stdout` only for parseable output.
4. **Context is always resolved first.** Every command starts by calling `context.resolve()`.
5. **Tokens come from env vars in v0.x.** No keychain/config token logic until v1.0.
