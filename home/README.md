# nori-cloud Homelab Infrastructure

Infrastructure-as-Code for a Talos Linux homelab using OpenTofu, Helm, and Argo CD.

## Quick Start

```bash
cp .env.example .env   # Configure secrets
tofu init
./bootstrap.sh --action plan
./bootstrap.sh --action apply
```

## Architecture

Three-tier deployment with strict dependencies:

```
cluster → networking → system
```

| Layer | Purpose |
|-------|---------|
| **cluster/** | Kubernetes namespace discovery from existing Talos cluster |
| **networking/** | Tailscale VPN, Traefik ingress, cert-manager (TLS) |
| **system/** | Argo CD, Teleport, core infrastructure services |

## Modules

### Core Layers

- **[cluster/](cluster/)** - Kubernetes foundation and Talos Linux configuration
- **[networking/](networking/)** - Dual-access networking (VPN + public), TLS certificates
- **[system/](system/)** - GitOps and zero-trust access services

### Supporting Modules

| Module | Purpose |
|--------|---------|
| **[_argocd/](_argocd/)** | Argo CD deployment and ApplicationSet configuration |
| **[_authentik/](_authentik/)** | Identity provider and OIDC for Traefik middleware |
| **[_democratic-csi/](_democratic-csi/)** | TrueNAS iSCSI/NFS storage provisioning |
| **[_external-secrets/](_external-secrets/)** | Infisical secret synchronization |

### Utilities

- **[script/](script/)** - Helper scripts for OAuth and secret management
- **[docs/](docs/)** - Hardware specs and system requirements
- **bootstrap.sh** - Orchestrates layered deployment

## Key Files

| File | Description |
|------|-------------|
| `main.tf` | Root module composition and provider configuration |
| `bootstrap.sh` | Deployment orchestration (`--action plan\|apply\|destroy`) |
| `.env` | Secrets (gitignored) - copy from `.env.example` |
| `vars.auto.tfvars` | Auto-loaded Terraform variables |

## State Management

- **Backend**: S3 bucket `infra-tf-033b4055b800d083` (ap-southeast-2)
- **Tool**: OpenTofu (`tofu` command, not `terraform`)

## Related

- **/apps/** - Application manifests deployed via Argo CD ApplicationSet
