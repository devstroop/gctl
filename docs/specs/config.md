# Config Schema

File: `~/.gitctl/config.json`

```json
{
  "accounts": [
    {
      "name": "personal",
      "provider": "github"
    },
    {
      "name": "work",
      "provider": "gitlab",
      "url": "https://gitlab.company.com"
    }
  ],
  "defaults": {
    "provider": "auto"
  }
}
```

## Design

Flat accounts array from day one — not nested under providers. Each account has a `name` for disambiguation when multiple accounts exist per provider. The optional `url` field enables self-hosted instances.

## Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `accounts[].name` | string | yes | Unique account identifier (e.g., `personal`, `work`) |
| `accounts[].provider` | string | yes | Provider name: `github`, `gitlab`, `gitea`, `custom` |
| `accounts[].url` | string | no | Base API URL for self-hosted instances |
| `defaults.provider` | string | yes | Default provider: `auto` or a specific provider name |
