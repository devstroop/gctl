# Error Handling

| Error class | User-facing message |
|---|---|
| No git repo | `Not a git repository. Run gitctl inside a git repo.` |
| No remote | `No git remote found. Add a remote with 'git remote add'.` |
| Unknown provider | `Could not detect provider from remotes. Run 'gitctl context'.` |
| No token | `No token for {provider}. Set {ENV}_TOKEN or run 'gitctl auth login'.` |
| 401 Unauthorized | `Authentication failed. Check your token or run 'gitctl auth login'.` |
| 404 Not Found | `Repository {owner}/{repo} not found on {provider}.` |
| 429 Rate Limited | `Rate limited by {provider}. Retrying in Xs...` (auto-retry) |
| Network error | `Could not connect to {provider}. Check your connection.` |
| Unsupported operation | `{provider} does not support {command}.` |

## Implementation

Error propagation uses Zig's explicit error union types throughout. All `gitctl` errors are either:
- Returned as error unions from provider functions
- Caught and translated to user-friendly messages in `src/main.zig`

Provider API errors (4xx/5xx) are surfaced with the full response body for debugging.
