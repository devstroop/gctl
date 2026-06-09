# Contributing

Thank you for considering contributing to `gitctl`.

## Project Overview

`gitctl` is a cross-forge Git CLI. It detects your provider from the git remote, resolves your auth token, and calls the provider API. One binary. No runtime. No dependencies beyond the Zig compiler.

All API providers are implemented as capability vtables (`RepoVtable`, `IssueVtable`, `PRVtable`, `LabelVtable`). Each provider module (`github.zig`, `gitlab.zig`) fills in the vtables it supports. Adding a provider means implementing these vtables for that API.

## Prerequisites

- [Zig](https://ziglang.org/) 0.15 or later
- `git`

No other dependencies. The project uses Zig stdlib only — no external packages, no libgit2, no HTTP libraries.

## Build and Test

```sh
# Build the binary
zig build

# Run all tests
zig build test

# Build and run in one step
zig build && zig build test
```

There is no test framework beyond `test` blocks in source files. Tests are run with `zig build test`.

## Getting Started

1. Pick an open issue or suggest a change
2. Discuss the approach (issues or a quick PR description)
3. Branch from the latest `main`
4. Implement
5. Add or update tests
6. Run `zig build && zig build test` — both must pass
7. Open a pull request

## Code Conventions

### Zig Standard Library Only

Every piece of functionality must use Zig stdlib. No third-party dependencies.

- HTTP requests: use `std.http` or the project's `http/client.zig` helpers
- JSON parsing: use `std.json`
- CLI parsing: extend `src/cli/args.zig`
- Auth: extend `src/auth/mod.zig`

### Naming

| Category               | Convention                        |
| ---------------------- | --------------------------------- |
| Types                  | PascalCase (`RepoInfo`)           |
| Functions              | camelCase (`repoView`)            |
| Private functions      | camelCase without `_` prefix      |
| Constants              | UPPER_SNAKE_CASE (`BASE_URL`)     |
| Files                  | kebab-case (`build.zig.zon`)      |
| Test files             | `*_test.zig` in `tests/`          |

### Capability Vtables

Each provider capability is an optionally-typed vtable:

```zig
pub const IssueVtable = struct {
    list: *const fn (...) anyerror![]IssueInfo,
    view: *const fn (...) anyerror!IssueInfo,
    create: *const fn (...) anyerror!IssueInfo,
    close: *const fn (...) anyerror!IssueInfo,
};
```

New provider methods follow this pattern:
1. Add the function pointer to the vtable struct in `src/providers/types.zig`
2. Implement the function in each provider (`github.zig`, `gitlab.zig`)
3. If not yet supported, return `error.NotSupported` (not `@compileError`)
4. Add the CLI command in `src/cli/args.zig`
5. Wire the dispatch in `src/providers/mod.zig`

### Error Handling

- Return Zig errors from vtable functions
- Print user-facing errors to stderr in dispatch functions (`providers/mod.zig`)
- Use `std.process.exit(1)` for fatal errors after printing
- Do not panic with `try` in CLI-facing code — catch and report

### Formatting

The project does not currently enforce `zig fmt`. When in doubt, match the style of surrounding code.

## Testing

Tests live in `tests/` and mirror the source structure:

```
tests/
  context_test.zig          → src/context/
  cli_test.zig              → src/cli/
  github_test.zig           → src/providers/github.zig
  gitlab_test.zig           → src/providers/gitlab.zig
```

### Types of Tests

- **Unit tests**: inline `test` blocks in source files for internal functions
- **JSON parsing tests**: in `*_test.zig` — parse mock API responses and assert field values
- **CLI tests**: in `cli_test.zig` — feed args to `parseArgs()` and assert the `ParsedArgs` result
- **Context tests**: in `context_test.zig` — feed remote URLs and assert provider/owner/repo

### Adding Tests

When you add a new provider function, add corresponding JSON parsing tests. Mock the API response as a string literal:

```zig
test "parse repo response" {
    const json =
        \\{"name": "gitctl", "full_name": "devstroop/gitctl", ...}
    ;
    // parse and assert fields
}
```

### Running Tests

```sh
# Full suite
zig build test

# Summary only
zig build test --summary all
```

## Git Workflow and Branching Policy

### Overview

This project follows **GitHub Flow**.

The `main` branch is always considered deployable and remains the single source of truth. All work is performed on short-lived branches created from `main` and merged back through pull requests.

There are no long-running integration branches such as `develop`, and no release branches before v1.0.

```text
main → feat/something → PR (squash) → main
```

### Branch Rules

- All branches must be created from the latest `main`
- One logical change per branch
- Prefer incremental delivery over large feature branches
- Rebase on the latest `main` before merge
- Delete branches after merge

### Branch Naming

```
<type>/<short-description>
```

Examples: `feat/gitlab-issues`, `fix/auth-token-refresh`, `docs/provider-guide`.

| Type       | Purpose                                          |
| ---------- | ------------------------------------------------ |
| `feat`     | New functionality                                |
| `fix`      | Bug fixes                                        |
| `docs`     | Documentation changes                            |
| `refactor` | Internal restructuring without behaviour changes |
| `test`     | Test additions or corrections                    |
| `perf`     | Performance improvements                         |
| `chore`    | Tooling, dependencies, configuration             |
| `ci`       | CI/CD workflow changes                           |
| `spike`    | Experimental or exploratory work                 |

### Commit Convention

Commits follow [Conventional Commits](https://www.conventionalcommits.org/).

```
feat(gitlab): add issue list support
fix(auth): handle expired tokens
docs(cli): document mirror commands
refactor(config): simplify schema loading
test(context): add SSH remote parsing tests
```

### Pull Requests

All changes enter `main` through a pull request. Requirements:

- Branch is rebased onto the latest `main`
- `zig build && zig build test` passes
- PR is reviewed before merge
- Merged using **Squash and Merge**

The squash commit message follows Conventional Commit format.

### Branch Protection

The `main` branch should be protected on the remote:

- Direct pushes disabled
- Pull request required
- Status checks required
- Branch must be up to date before merge
- Automatic branch deletion enabled after merge

### Release Strategy

**Before v1.0**: no release branches, no hotfix branches — all work merges directly into `main`.

**After v1.0**: release branches (`release/v1.x`) for patch maintenance, hotfix branches (`hotfix/desc`) for urgent fixes, merged into both the active release branch and `main`.

### Standard Workflow

```sh
# Sync main
git checkout main
git pull

# Create branch
git checkout -b feat/gitlab-issues

# Develop
zig build
zig build test

# Commit incrementally
git commit -m "feat(gitlab): add issue list endpoint"
git commit -m "test(gitlab): add issue parsing tests"

# Push and open PR
git push -u origin feat/gitlab-issues
gh pr create

# Merge via squash
gh pr merge --squash

# Cleanup
git checkout main
git pull
git branch -d feat/gitlab-issues
```

## Questions

Open an issue at https://github.com/devstroop/gitctl/issues for questions or discussions.
