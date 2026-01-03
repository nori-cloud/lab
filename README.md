# Nori-Cloud Infra

This repo manages the infrastructure code for the nori-cloud collection.

## Development Environment

### Prerequisites

Copy the example environment file and configure your secrets:

```bash
cp .devcontainer/.env.example .devcontainer/.env
```

Edit `.devcontainer/.env` with your actual values:

| Variable | Description |
|----------|-------------|
| `GRAFANA_URL` | Grafana instance URL |
| `GRAFANA_SERVICE_ACCOUNT_TOKEN` | Service account token for Grafana MCP |

### MCP Servers

The `.mcp.json` configures MCP servers for Claude Code:

- **grafana** - Interact with Grafana dashboards, datasources, and alerts

Tokens are loaded from environment variables (not stored in `.mcp.json`).
