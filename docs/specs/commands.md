# Command Reference

## v0.1 — Read-Only Operations

```
gctl doctor [--quick]
    Full system diagnostics.
    Checks: git repo, remotes, provider resolution, token presence,
    supported capabilities, API connectivity.
    Use --quick to skip API calls for instant local-only info.

gctl status
    Repo pulse: open issues, open PRs, latest activity.
    Requires a token (makes API calls to the provider).

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

## v0.4 — Cross-Provider Operations

All cross-provider commands use REST-style resource paths: `[<remote>/]<type>/[<id>]`.

```
gctl network
    Show all remotes with provider, owner, repo, and status.
    Built on multi-context — parses every fetch remote.

gctl copy <source-path> <target-remote>
    Copy a resource from the current repo to another remote.
    Examples:
      gctl copy issues/14 upstream
      gctl copy prs/42 upstream

gctl diff <type> <remote>
    Show resources present in current repo but missing on target.
    Examples:
      gctl diff issues upstream       # issues missing in upstream
      gctl diff prs upstream          # PRs missing in upstream

gctl export <resource-path>
    Write a resource as JSON to stdout.
    Examples:
      gctl export issues/14
      gctl export issues/             # all issues (JSON array)
      gctl export upstream/issues/    # all issues from upstream remote

gctl import <resource-path>
    Read JSON from stdin and create a resource.
    Examples:
      gctl import upstream/issues/ < issue.json
```

### Pipe Model

export/import are designed as Unix filters — they read from or write to
stdout/stdin, enabling arbitrary composition:

```sh
# Copy a resource (export piped to import internally)
gctl copy issues/14 upstream

# Equivalent manual pipe
gctl export issues/14 | gctl import upstream/issues/

# Inspect before importing
gctl export issues/14 > issue.json
vim issue.json
gctl import upstream/issues/ < issue.json

# Bulk copy all issues
gctl export issues/ | gctl import upstream/issues/

# Chain with jq
gctl export issues/ | jq '.[] | {title, body}'
```

### Resource Path Resolution

- Paths without a remote prefix resolve to the current context (`contexts[0]`)
- `export` with no id (e.g., `export issues/`) lists all resources of that type
- Remote is matched against git remote names, then against context names from config
- Explicit remote prefix overrides current context

### Capability Requirements

All cross-provider operations require both source and target providers to support
the resource type (matching vtables must be non-null). If either side doesn't
support the type, a clear error is returned.

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
