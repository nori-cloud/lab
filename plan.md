# Plan: Host OpenClaw as a nori-cloud App

## What is OpenClaw?

OpenClaw is a self-hosted autonomous AI agent / personal assistant. It provides a web UI (gateway on port 18789), supports multiple chat channels (WhatsApp, Telegram, Slack, etc.), can execute shell commands, browse the web, and manage workflows via LLMs. It requires PostgreSQL for persistence and persistent storage for its memory/config system.

- **Official image**: `ghcr.io/openclaw/openclaw:main`
- **Stateful**: Single-user, single-replica application
- **Database**: PostgreSQL (can reuse existing `postgres.nori-cloud` instance)
- **Ports**: 18789 (gateway/web UI), 18790 (bridge, internal)
- **Storage**: Needs persistent volume for `~/.openclaw` (config, memory, API keys)
- **Secrets**: LLM API keys (Anthropic, OpenAI, etc.), database credentials

## Architecture Decision

OpenClaw will be deployed as a **Deployment** with a separate **PVC** for persistent storage. It will:

- Use pre-existing **PostgreSQL** database (already provisioned)
- Use **Infisical** (via ExternalSecret) for secret management (API keys, DB credentials)
- Expose the web UI via **Traefik IngressRoute** at `openclaw.norriswu.me`
- Use `freenas-nfs` storage class for the PVC

## Files to Create

All files go in `apps/openclaw/`:

### 1. `kustomization.yaml`
Standard Kustomize resource list:
```yaml
resources:
  - external-secret.yaml
  - pvc.yaml
  - deployment.yaml
  - service.yaml
  - ingress-route.yaml
```

### 2. `pvc.yaml`
PersistentVolumeClaim:
- Name: `openclaw-data`
- StorageClass: `freenas-nfs`
- AccessMode: `ReadWriteOnce`
- Size: 10Gi

### 3. `deployment.yaml`
Deployment with:
- Image: `ghcr.io/openclaw/openclaw:main`
- Replicas: 1
- Container port: 18789 (gateway)
- Environment variables:
  - `OPENCLAW_GATEWAY_PORT=18789`
  - `DATABASE_URL` from secret (pointing to pre-existing postgres)
- `envFrom` referencing `openclaw-secret`
- Volume mount: `/home/node/.openclaw` using `openclaw-data` PVC
- Startup probe on port 18789
- Resource requests/limits (256Mi/2Gi memory, 100m/1000m CPU)

### 4. `service.yaml`
ClusterIP service exposing port 18789 (gateway web UI).

### 5. `ingress-route.yaml`
Traefik IngressRoute:
- Host: `openclaw.norriswu.me`
- EntryPoint: `websecure`
- Routes to `openclaw` service on port 18789

### 6. `external-secret.yaml`
ExternalSecret pulling from Infisical (`infisical-nori-cloud` SecretStore):
- `ANTHROPIC_API_KEY` - for Claude models
- `OPENAI_API_KEY` - for OpenAI models (optional)
- `DATABASE_URL` - PostgreSQL connection string
- Any additional channel credentials (can be added later)

Secrets will need to be populated in Infisical under `/openclaw/` path.

## File to Modify

### 7. `apps/nori-cloud/application-set.yaml`
Add `- app: openclaw` to the list generator elements.

## Post-Deployment Steps (Manual)

1. **Populate secrets in Infisical** under the `/openclaw/` path:
   - `OPENCLAW_ANTHROPIC_API_KEY`
   - `OPENCLAW_OPENAI_API_KEY` (optional)
   - `OPENCLAW_DATABASE_URL` (connection string to pre-existing postgres)
2. **Verify Argo CD sync**: `kubectl get application openclaw -n argo-cd`
3. **Access**: Navigate to `https://openclaw.norriswu.me`

## Security Considerations

- OpenClaw executes code inside its container -- this is by design but means container isolation is important
- No shell access or host mounts beyond the data volume
- Network access is limited to cluster-internal services + egress for LLM APIs
- Secrets (API keys) managed exclusively through Infisical, never in git
