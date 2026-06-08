# Provider API Mappings

## GitHub

Base URL: `https://api.github.com`

| gctl command        | API endpoint                                     |
|---------------------|--------------------------------------------------|
| `repo view`         | `GET /repos/{o}/{r}`                             |
| `repo create`       | `POST /user/repos` or `POST /orgs/{o}/repos`     |
| `repo delete`       | `DELETE /repos/{o}/{r}`                          |
| `repo archive`      | `PATCH /repos/{o}/{r}` (`{"archived": true}`)    |
| `label set_all`     | DELETE existing + POST each new `/repos/{o}/{r}/labels` |
| `issue list`        | `GET /repos/{o}/{r}/issues`                      |
| `issue view`        | `GET /repos/{o}/{r}/issues/{n}`                  |
| `issue create`      | `POST /repos/{o}/{r}/issues`                     |
| `issue close`       | `PATCH /repos/{o}/{r}/issues/{n}`                |
| `pr list`           | `GET /repos/{o}/{r}/pulls`                       |
| `pr view`           | `GET /repos/{o}/{r}/pulls/{n}`                   |
| `api`               | Any method + path against `api.github.com`       |

---

## GitLab

Base URL: `https://gitlab.com/api/v4`

`pr` commands map to GitLab Merge Requests under the hood. The CLI surface stays uniform.

| gctl command        | GitLab API endpoint                             |
|---------------------|-------------------------------------------------|
| `repo view`         | `GET /projects/{id}`                            |
| `repo create`       | ❌ (NotSupported stub)                          |
| `repo delete`       | ❌ (NotSupported stub)                          |
| `repo archive`      | ❌ (NotSupported stub)                          |
| `label set_all`     | ❌ (NotSupported stub)                          |
| `issue list`        | `GET /projects/{id}/issues`                     |
| `issue view`        | `GET /projects/{id}/issues/{n}`                 |
| `issue create`      | ❌ (NotSupported stub)                          |
| `issue close`       | ❌ (NotSupported stub)                          |
| `pr list`           | `GET /projects/{id}/merge_requests`             |
| `pr view`           | `GET /projects/{id}/merge_requests/{n}`         |
| `api`               | Any method + path against `gitlab.com/api/v4`   |

`{id}` is the URL-encoded project path (e.g., `devstroop%2Fgctl`).

---

## Custom

Custom providers map to a user-supplied `--provider-url`. All capabilities are `null` by default. Use `gctl api` for raw HTTP access against the custom endpoint.

```sh
gctl --provider custom --provider-url https://git.example.com/api/v1 api GET /repos/owner/repo
```

The `TOKEN` environment variable is used for authentication with custom providers.
