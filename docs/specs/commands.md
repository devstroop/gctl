# Command Reference

## Read-Only Operations

```
gitctl doctor [--quick]
    Full system diagnostics.
    Checks: git repo, remotes, provider resolution, token presence,
    supported capabilities, API connectivity.
    Use --quick to skip API calls for instant local-only info.

gitctl status
    Repo pulse: open issues, open PRs, latest activity.
    Requires a token (makes API calls to the provider).

gitctl repo view [owner/repo]
    Show repository details (description, stars, forks, visibility).

gitctl issue list
    List open issues in the current repo.

gitctl issue view <number>
    Show issue details (title, author, state, body).

gitctl pr list
    List open pull/merge requests.

gitctl pr view <number>
    Show PR/MR details (title, state, draft, branches).

gitctl api <method> <path>
    Direct API call. Escape hatch for unsupported operations.
    Example: gitctl api GET /user
```

### Custom Provider Usage

```sh
# Point at any Git forge with a REST API
gitctl --provider custom --provider-url https://git.example.com/api/v1 context

# Flags work before or after the command
gitctl context --provider custom --provider-url https://git.example.com/api/v1

# Equals-style flags
gitctl --provider=custom --provider-url=https://git.example.com/api/v1 context
```

Custom providers have all capabilities set to `null` — use `gitctl api` as an escape hatch for raw API access.

---

## GitLab Support

All read-only/write operations, plus GitLab support via `GITLAB_TOKEN`.
`gitctl pr` commands map to GitLab merge requests automatically.

---

## Write Operations

```
gitctl repo create <name>
    Create a repository.
    Flags: --private, --description <text>

gitctl repo delete <name>
    Delete a repository.

gitctl repo archive <name>
    Archive a repository.

gitctl label set_all <labels>
    Replace all repo labels with a comma-separated list.
    Example: gitctl label set_all "bug,feature,urgent"

gitctl issue create <title>
    Create an issue. Returns number, title, state, URL.

gitctl issue close <number>
    Close an issue.

gitctl pr create <title>
    Create a pull/merge request.
    Flags: --draft (planned)

gitctl pr merge <number>
    Merge a pull/merge request.
    Flags: --squash, --message (planned)
```

---

## Cross-Provider Operations

All cross-provider commands use REST-style resource paths: `[<remote>/]<type>/[<id>]`.

```
gitctl network [--all]
    Show all remotes with provider, owner, repo.
    Uses multi-context resolution — parses every fetch remote.
    --all shows raw URLs in a table format.

gitctl copy <source-path> <target-remote>
    Copy a resource from the current repo to another remote.
    Examples:
      gitctl copy issues/14 upstream
      gitctl copy prs/42 upstream

gitctl diff <type> <remote>
    Show resources present in current repo but missing on target.
    Examples:
      gitctl diff issues upstream       # issues missing in upstream
      gitctl diff prs upstream          # PRs missing in upstream

gitctl export <resource-path>
    Write a resource as JSON to stdout.
    Examples:
      gitctl export issues/14
      gitctl export issues/             # all issues (JSON array)
      gitctl export upstream/issues/    # all issues from upstream remote

gitctl import <resource-path>
    Read JSON from stdin and create a resource.
    Examples:
      gitctl import upstream/issues/ < issue.json
```

### Pipe Model

export/import are designed as Unix filters — they read from or write to
stdout/stdin, enabling arbitrary composition:

```sh
# Copy a resource (export piped to import internally)
gitctl copy issues/14 upstream

# Equivalent manual pipe
gitctl export issues/14 | gitctl import upstream/issues/

# Inspect before importing
gitctl export issues/14 > issue.json
vim issue.json
gitctl import upstream/issues/ < issue.json

# Bulk copy all issues
gitctl export issues/ | gitctl import upstream/issues/

# Chain with jq
gitctl export issues/ | jq '.[] | {title, body}'
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

## Persistent Auth (planned)

```
gitctl auth login <provider>
    OAuth device flow (GitHub), PAT prompt (GitLab).

gitctl auth logout <provider>
    Remove stored credentials.

gitctl auth list
    Show all authenticated accounts.

gitctl auth status
    Show current auth context.
```
