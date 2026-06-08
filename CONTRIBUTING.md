# Git Workflow and Branching Policy

## Overview

This project follows **GitHub Flow**.

The `main` branch is always considered deployable and remains the single source of truth. All work is performed on short-lived branches created from `main` and merged back through pull requests.

There are no long-running integration branches such as `develop`, and no release branches before v1.0.

```text
main
 ├─ feat/something
 ├─ fix/something
 ├─ docs/something
 └─ ...
      ↓
      PR
      ↓
    squash
      ↓
     main
```

## Branch Rules

### Source Branch

All branches must be created from the latest `main`.

```sh
git checkout main
git pull
git checkout -b feat/example
```

### Branch Lifetime

Branches should remain short-lived.

Guidelines:

* One logical change per branch
* Prefer incremental delivery over large feature branches
* Rebase on the latest `main` before merge
* Delete branches after merge

## Branch Naming

Branch names follow:

```text
<type>/<short-description>
```

Examples:

```text
feat/gitlab-issues
fix/auth-token-refresh
docs/provider-guide
refactor/context-resolution
test/remote-parser
chore/dependency-updates
```

### Allowed Types

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

## Commit Convention

Commits follow Conventional Commits.

Examples:

```text
feat(gitlab): add issue list support
fix(auth): handle expired tokens
docs(cli): document mirror commands
refactor(config): simplify schema loading
test(context): add SSH remote parsing tests
```

### Commit Scope

Scopes are encouraged when a change affects a specific subsystem:

```text
feat(github):
feat(gitlab):
feat(auth):
fix(cli):
test(config):
```

## Pull Requests

All changes enter `main` through a pull request.

Requirements:

* Branch is rebased onto the latest `main`
* Build succeeds
* Tests pass
* Pull request is reviewed before merge
* Pull request is merged using **Squash and Merge**

The squash commit message should follow Conventional Commit format.

Example:

```text
feat(gitlab): add merge request support
```

## Branch Protection

The `main` branch should be protected.

Recommended settings:

* Direct pushes disabled
* Pull request required
* Status checks required
* Branch must be up to date before merge
* Automatic branch deletion enabled after merge

## Release Strategy

Before v1.0:

* No release branches
* No hotfix branches
* All work merges directly into `main`

After v1.0:

### Release Branches

Release maintenance occurs on dedicated release branches.

Examples:

```text
release/v1.0
release/v1.1
release/v2.0
```

Patch releases are cut from the appropriate release branch.

### Hotfix Branches

Urgent production fixes use:

```text
hotfix/<description>
```

Hotfixes are merged into both:

* The active release branch
* `main`

## Roadmap Planning

Branches are implementation details and should not be used as a roadmap.

Planned work is tracked separately by milestone, issue, or project board.

Examples:

```text
v0.2 GitLab Support
v0.3 Extended Operations
v0.4 Mirroring
v1.0 Authentication
```

Branch names are created only when implementation begins.

## Standard Workflow

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
