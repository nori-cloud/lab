# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Infrastructure-as-Code repository for **nori-cloud** managing homelab Talos Linux infrastructure using OpenTofu, Kubernetes, Helm, and Argo CD.

**Note**: The `/cloud/` directory contains historical reference code only and is not actively deployed.

## Architecture

### Three-Tier Infrastructure Pattern

The homelab infrastructure (`/home/`) follows a layered deployment model with strict dependencies:

**Homelab** (`/home/`):
1. `cluster/` → Kubernetes namespace discovery
2. `networking/` → Tailscale, Traefik, cert-manager (depends on cluster)
3. `system/` → Argo CD, Teleport, Authentik (depends on networking)

The bootstrap script (`bootstrap.sh`) enforces this ordering using targeted applies.

### State Management

- **Backend**: S3 bucket `infra-tf-033b4055b800d083` in `ap-southeast-2`
- **Key**: `infra-home/terraform.tfstate`
- State locking enabled

### Application Deployment Model

Applications in `/apps/` are deployed via **Argo CD ApplicationSet** (see `/apps/nori-cloud/application-set.yaml`):
- Automated sync with prune and self-heal
- Each app uses Kustomize manifests
- Apps are NOT deployed via direct kubectl/helm

### Secret Management Pattern

Secrets are created empty in Terraform, then populated using helper scripts:
- `/home/script/update-cert-manager-secret.sh` - Loads from `.env` and patches Kubernetes secret
- Pattern: `tofu apply` creates empty secret → run script to populate

## Common Commands

### Homelab Infrastructure

```bash
cd /workspace/lab/home/

# Bootstrap entire stack (cluster → networking → system)
./bootstrap.sh

# Only plan cluster layer
./bootstrap.sh --action plan

# Destroy all infrastructure
./bootstrap.sh --action destroy

# Manual targeted workflow
tofu init
tofu plan -target=module.cluster -out=.plan/cluster.tfplan
tofu apply .plan/cluster.tfplan
```

The Proxmox provider is currently **commented out** in `/home/main.tf` - homelab runs on existing Talos Linux cluster.

### Working with Applications

```bash
# Check Argo CD applications
kubectl get applications -n system
kubectl get applicationsets -n system

# View deployed apps
kubectl get all -n nori-cloud

# Argo CD manages apps - do NOT use kubectl apply directly on /apps/ manifests
```

## Key Patterns

### Bootstrap Script Behavior

The bootstrap script (`/home/bootstrap.sh`):
- Accepts `--action` flag: `plan`, `apply`, or `destroy`
- Stores plans in `.plan/` directory
- Checks for "No changes" before applying
- Uses `tofu` command (OpenTofu, not terraform)

### Helm Release Pattern

Helm charts deployed via Terraform `helm_release` resources:
- External charts: pinned versions from upstream repositories
- Custom charts: local directories in `networking/charts/` or `system/charts/`
- Values files: co-located YAML files (e.g., `traefik-values.yaml`)
- Config releases: separate helm_release for post-install configuration

### Variable Configuration

- `/home/.env` - Secrets (gitignored), sourced by scripts
- `/home/.env.example` - Template for required variables
- `/home/vars.auto.tfvars` - Auto-loaded Terraform variables
- Environment variables prefixed with `TF_VAR_` override Terraform variables

## Tool Requirements

- **OpenTofu** (`tofu`) - primary IaC tool (NOT terraform)
- **kubectl** - Kubernetes CLI
- **helm** - Kubernetes package manager

## Testing Infrastructure Changes

1. Use targeted plans: `tofu plan -target=module.X`
2. Apply one module at a time during testing
3. Verify Kubernetes resources: `kubectl get all -n <namespace>`
4. For Argo CD apps, check sync status: `kubectl get applications -n system`
5. Plans are saved to `.plan/` directory (gitignored)
