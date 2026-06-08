# Command Reference

## v0.1 — The Kernel (GitHub only, env var tokens)

```
gctl context
    Show detected provider, account, owner, repo, remote, token source.
    The debugging cornerstone. Shows API URL when --provider-url is set.

gctl status
    High-level summary of the current repo context.

gctl repo view [owner/repo]
    Show repository details.

gctl issue list
    List open issues in the current repo.

gctl issue view <number>
    Show issue details and comments.

gctl pr list
    List open pull requests in the current repo.

gctl pr view <number>
    Show PR details, status, and review state.

gctl api <method> <path>
    Direct API call. Escape hatch for unsupported operations.
    Example: gctl api GET /user
```

### Custom Provider Usage (v0.1+)

```sh
# Point at any Git forge with a REST API
gctl --provider custom --provider-url https://git.example.com/api/v1 context

# Flags work before or after the command
gctl context --provider custom --provider-url https://git.example.com/api/v1

# Equals-style flags
gctl --provider=custom --provider-url=https://git.example.com/api/v1 context
```

Custom providers have all capabilities set to `null` — use `gctl api` as an escape hatch for raw API access.

---

## v0.2 — GitLab

```
All v0.1 commands, plus GitLab support via GITLAB_TOKEN.
gctl pr list → shows merge requests.
```

---

## v0.3 — Create Operations

```
gctl issue create [--title] [--body]
    Create an issue. Interactive prompt if flags omitted.

gctl issue close <number>
    Close an issue.

gctl pr create [--title] [--body] [--draft] [--web]
    Create a pull request / merge request.

gctl pr merge <number>
    Merge a pull request.
```

---

## v0.4 — Releases + Gitea

```
gctl release list
    List releases.

gctl release view <tag>
    Show release details and assets.

gctl release create <tag>
    Create a release from a tag.
```

---

## v0.5 — Runs

```
gctl run list
    List recent CI/CD runs.

gctl run view <id>
    Show run details and job status.

gctl run rerun <id>
    Re-trigger a run.
```

---

## v1.0 — Persistent Auth & Polish

```
gctl auth login <provider>
    OAuth device flow (GitHub), PAT prompt (GitLab/Gitea).

gctl auth logout <provider>
    Remove stored credentials.

gctl auth list
    Show all authenticated accounts.

gctl auth status
    Show current auth context.

gctl doctor
    Diagnose config, git, tokens, connectivity, keychain.

gctl completion <bash|zsh|fish>
    Generate shell completion script.
```
