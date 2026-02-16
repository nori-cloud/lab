# OpenClaw Authentik Authentication Design

## Goal

Protect OpenClaw behind Authentik authentication using Traefik forward auth middleware and OpenClaw's trusted proxy mode.

## Architecture

```
User → openclaw.norriswu.me
         ↓
      Traefik (IngressRoute)
         ↓
      Middleware (forwardAuth)
         ↓
      Authentik Outpost → validates session/redirects to login
         ↓
      OpenClaw (trusts X-authentik-email header)
```

## Approach

ConfigMap-based configuration:
- Traefik Middleware in `nori-cloud` namespace for forward auth
- ConfigMap with OpenClaw JSON config for trusted proxy mode
- Mount config to `/home/node/.openclaw/config.json`

## New Files

### `apps/openclaw/middleware.yaml`

Traefik forward auth middleware pointing to Authentik outpost.

```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: authentik
  namespace: nori-cloud
spec:
  forwardAuth:
    address: "http://authentik.norriswu.me/outpost.goauthentik.io/auth/traefik"
    trustForwardHeader: true
    authResponseHeaders:
      - X-authentik-username
      - X-authentik-email
      - X-authentik-uid
```

### `apps/openclaw/configmap.yaml`

OpenClaw trusted proxy configuration.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: openclaw-config
  namespace: nori-cloud
data:
  config.json: |
    {
      "gateway": {
        "auth": {
          "mode": "trusted-proxy",
          "trustedProxy": {
            "userHeader": "X-authentik-email"
          }
        },
        "trustedProxies": ["10.0.0.0/8"]
      }
    }
```

## Modified Files

### `apps/openclaw/ingress-route.yaml`

Add middleware reference to route.

### `apps/openclaw/deployment.yaml`

Mount configmap as `/home/node/.openclaw/config.json`.

### `apps/openclaw/kustomization.yaml`

Add `configmap.yaml` and `middleware.yaml` to resources.

## Pre-requisites

Authentik setup (already done):
- Application created for OpenClaw
- Proxy Provider (Forward Auth - single application)
- Assigned to Outpost

## Security Notes

- `trustedProxies: ["10.0.0.0/8"]` covers k8s pod network; narrow if needed
- Single-user setup; no user allowlist required
- All auth delegated to Authentik
