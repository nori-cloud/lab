# Minecraft

Minecraft server management using [Crafty Controller](https://craftycontrol.com/), deployed via Argo CD.

**App directory**: `minecraft`
**Resource names**: `crafty-*`

## Overview

[Crafty Controller](https://craftycontrol.com/) is a Minecraft server wrapper that allows management of multiple servers from a single unified panel. It provides:

- Multi-server management (vanilla, modded, Bedrock, different versions)
- Web-based console access
- Server scheduling and automation
- Backup management
- User management with role-based access

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│ Pod: crafty                                                  │
│                                                              │
│  ┌─────────────────┐         ┌─────────────────┐             │
│  │  crafty         │         │  playit         │             │
│  │  (panel + mc)   │         │  (tunnel agent) │             │
│  │  :8443 :25565+  │         │  :80/:443       │             │
│  └─────────────────┘         └─────────────────┘             │
│           │                          │                       │
│  ┌────────┴──────────────────────────┘                       │
│  │                                                           │
│  │  PVC: crafty-data (100Gi)                                 │
│  │  - /backups, /logs, /servers, /config, /import            │
│  └───────────────────────────────────────────────────────────┘
└──────────────────────────────────────────────────────────────┘
```

## Access

- **Web UI**: https://mc.norriswu.me (via Traefik IngressRoute)
- **Minecraft servers**: Via Playit.gg tunnel

### Services

| Service | Type | Ports | Purpose |
|---------|------|-------|---------|
| crafty | ClusterIP | 8443 | Web UI (HTTPS via Traefik) |
| crafty | ClusterIP | 8123 | Dynmap |
| crafty | ClusterIP | 19132/udp | Bedrock servers |
| crafty | ClusterIP | 25565-25567 | Minecraft servers |

## Storage

| Volume | Size | Purpose |
|--------|------|---------|
| crafty-data | 30Gi | All Crafty data (servers, backups, config, logs) |

Crafty uses subPaths within a single PVC:
- `/crafty/backups` - Server backups
- `/crafty/logs` - Application logs
- `/crafty/servers` - Game server files
- `/crafty/app/config` - Configuration and database
- `/crafty/import` - Server import directory

## Requirements

- **Storage class**: `freenas-nfs` must be available

## Environment Variables

| Variable | Value | Description |
|----------|-------|-------------|
| TZ | Australia/Sydney | Timezone |

## Minecraft Server Ports

Minecraft server ports (25565-25567) are exposed externally via [Playit.gg](https://playit.gg) tunnel.

### Playit.gg Setup

1. Create an account at https://playit.gg
2. Create a new agent at https://playit.gg/account/agents/new-docker
3. Copy the secret key and add it to Infisical:
   - Path: `/minecraft/PLAYIT_SECRET_KEY`
4. In the Playit dashboard, create tunnels for your Minecraft ports (25565-25567)
5. Players connect using the Playit-provided address (e.g., `your-tunnel.joinmc.link`)

### Architecture

```
External players → Playit.gg cloud → playit-agent → Crafty MC servers
Local players    → ClusterIP:25565+ → Crafty MC servers
```

### Port Allocation

| Port | Usage |
|------|-------|
| 25565 | Primary server / proxy |
| 25566-25567 | Additional servers |
| 19132/udp | Bedrock server |

Configure each Minecraft server in Crafty with a unique port, then create matching tunnels in Playit dashboard.

## Initial Setup

On first launch, Crafty will display the initial admin credentials in the container logs:

```bash
kubectl logs -n nori-cloud crafty-0 -c crafty | grep -A5 "password"
```

Access the web UI at https://mc.norriswu.me and log in with the generated credentials.
