# Provider API Mappings

## GitHub

Base URL: `https://api.github.com`

| gctl command  | API endpoint                          |
|---------------|---------------------------------------|
| `issue list`  | `GET /repos/{o}/{r}/issues`           |
| `issue view`  | `GET /repos/{o}/{r}/issues/{n}`       |
| `issue create`| `POST /repos/{o}/{r}/issues`          |
| `issue close` | `PATCH /repos/{o}/{r}/issues/{n}`     |
| `pr list`     | `GET /repos/{o}/{r}/pulls`            |
| `pr view`     | `GET /repos/{o}/{r}/pulls/{n}`        |
| `pr create`   | `POST /repos/{o}/{r}/pulls`           |
| `pr merge`    | `PUT /repos/{o}/{r}/pulls/{n}/merge`  |
| `run list`    | `GET /repos/{o}/{r}/actions/runs`     |
| `run view`    | `GET /repos/{o}/{r}/actions/runs/{id}`|
| `run rerun`   | `POST /repos/{o}/{r}/actions/runs/{id}/rerun` |
| `release list`| `GET /repos/{o}/{r}/releases`         |

---

## GitLab

Base URL: `https://gitlab.com/api/v4`

`pr` commands map to GitLab Merge Requests under the hood. The CLI surface stays uniform.

| gctl command  | GitLab API endpoint                        |
|---------------|--------------------------------------------|
| `issue list`  | `GET /projects/{id}/issues`                |
| `pr list`     | `GET /projects/{id}/merge_requests`        |
| `run list`    | `GET /projects/{id}/pipelines`             |

---

## Gitea / Forgejo

Gitea and Forgejo share an identical REST API (`/api/v1`).

| gctl command  | Gitea API endpoint                     |
|---------------|----------------------------------------|
| `issue list`  | `GET /repos/{o}/{r}/issues`            |
| `pr list`     | `GET /repos/{o}/{r}/pulls`             |
| `run list`    | Not supported (`pipelines = null`)     |

---

## Custom

Custom providers map to a user-supplied `--provider-url`. All capabilities are `null` by default. Use `gctl api` for raw HTTP access against the custom endpoint.

```sh
gctl --provider custom --provider-url https://git.example.com/api/v1 api GET /repos/owner/repo
```

The `TOKEN` environment variable is used for authentication with custom providers.
