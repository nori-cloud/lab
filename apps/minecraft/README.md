# Minecraft

Minecraft server management using [DiscoPanel](https://github.com/nickheyer/discopanel), deployed via Argo CD.

**App directory**: `minecraft`
**Resource names**: `disco-panel-*`

## Overview

[DiscoPanel](https://github.com/nickheyer/discopanel) is a lightweight modded Minecraft server hosting suite and management web app. It provides:

- Multi-server management (vanilla, modded, different versions)
- Smart proxy system with custom hostnames
- CurseForge modpack integration
- Live console access and RCON support
- Resource management per server

## Architecture

Since this runs on a Talos cluster (containerd-only, no Docker), we use a Docker-in-Docker (DinD) sidecar pattern:

```
┌──────────────────────────────────────────────────────────────┐
│ Pod: disco-panel                                             │
│                                                              │
│  ┌─────────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │  disco-panel    │  │  dind        │  │  playit         │  │
│  │  (web UI)       │──│  (docker)    │  │  (tunnel agent) │  │
│  │  :8080          │  │  :2375       │  │  :80/:443       │  │
│  └─────────────────┘  └──────────────┘  └─────────────────┘  │
│                              │                   │           │
│  ┌───────────────────────────┴───────────────────┘           │
│  │                                                           │
│  │  PVC: disco-data (shared)         PVC: dind-storage       │
│  └───────────────────────────────────────────────────────────┘
└──────────────────────────────────────────────────────────────┘
```

## Access

- **Web UI**: https://disco-panel.norriswu.me (via Traefik IngressRoute)
- **Playit tunnel**: Local LAN via MetalLB LoadBalancer on ports 80/443

### Services

| Service | Type | Ports | Purpose |
|---------|------|-------|---------|
| disco-panel | ClusterIP | 8080 | Web UI (Traefik) |
| disco-panel-playit | LoadBalancer | 80, 443 | Playit tunnel (MetalLB) |

## Storage

| Volume | Size | Purpose |
|--------|------|---------|
| disco-data | 50Gi | Minecraft server data, configs |
| dind-storage | 100Gi | Docker images, containers |

## Requirements

- **Privileged pods**: DinD requires privileged security context
- **Storage class**: `freenas-nfs` must be available

If Pod Security Standards are enforced, the namespace may need:

```yaml
pod-security.kubernetes.io/enforce: privileged
```

## Environment Variables

| Variable | Value | Description |
|----------|-------|-------------|
| DISCOPANEL_DATA_DIR | /app/data | Data directory inside container |
| DOCKER_HOST | tcp://localhost:2375 | Connection to DinD sidecar |
| TZ | Australia/Sydney | Timezone |

## Minecraft Server Ports

Minecraft server ports (25565-25575) are exposed externally via [Playit.gg](https://playit.gg) tunnel.

### Playit.gg Setup

1. Create an account at https://playit.gg
2. Create a new agent at https://playit.gg/account/agents/new-docker
3. Copy the secret key and add it to Infisical:
   - Path: `/disco-panel/PLAYIT_SECRET_KEY`
4. In the Playit dashboard, create tunnels for your Minecraft ports (25565-25575)
5. Players connect using the Playit-provided address (e.g., `your-tunnel.joinmc.link`)

### Architecture

```
External players → Playit.gg cloud → MetalLB IP:80/443 → playit-agent → DinD → MC servers
Local players    → MetalLB IP:80/443 → playit-agent → DinD → MC servers
```

### Port Allocation

| Port | Usage |
|------|-------|
| 25565 | Primary server / proxy |
| 25566-25575 | Additional servers |

Configure each Minecraft server in DiscoPanel with a unique port, then create matching tunnels in Playit dashboard.
