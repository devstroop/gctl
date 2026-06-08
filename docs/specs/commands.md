# Command Reference

## v0.1 — Context & Read-Only Operations

```
gctl context
    Show detected provider, owner, repo, remote, token source.
    Debugging cornerstone.

gctl status
    High-level summary: provider → owner/repo.

gctl repo view [owner/repo]
    Show repository details (description, stars, forks, visibility).

gctl issue list
    List open issues in the current repo.

gctl issue view <number>
    Show issue details (title, author, state, body).

gctl pr list
    List open pull/merge requests.

gctl pr view <number>
    Show PR/MR details (title, state, draft, branches).

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

All v0.1 commands, plus GitLab support via `GITLAB_TOKEN`.
`gctl pr` commands map to GitLab merge requests automatically.

---

## v0.3 — Write Operations

```
gctl repo create <name>
    Create a repository.
    Flags: --private, --description <text>

gctl repo delete <name>
    Delete a repository.

gctl repo archive <name>
    Archive a repository.

gctl label set_all <labels>
    Replace all repo labels with a comma-separated list.
    Example: gctl label set_all "bug,feature,urgent"

gctl issue create <title>
    Create an issue. Returns number, title, state, URL.

gctl issue close <number>
    Close an issue.

gctl pr create <title>
    Create a pull/merge request.
    Flags: --draft (planned)

gctl pr merge <number>
    Merge a pull/merge request.
    Flags: --squash, --message (planned)
```

---

## v0.4 — Mirror

```
gctl mirror list
    List configured mirrors.

gctl mirror setup <source> <target>
    Configure a mirror between two repos/providers.

gctl mirror run <name>
    Execute a mirror sync.
```

---

## v1.0 — Persistent Auth

```
gctl auth login <provider>
    OAuth device flow (GitHub), PAT prompt (GitLab).

gctl auth logout <provider>
    Remove stored credentials.

gctl auth list
    Show all authenticated accounts.

gctl auth status
    Show current auth context.
```
