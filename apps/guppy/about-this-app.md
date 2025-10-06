# Guppy Application

A web application deployed in the nori-cloud infrastructure with automated database migrations and health monitoring.

## What is Guppy

Guppy is a containerized web application that:

- Serves content on port 3000
- Requires database migrations before deployment
- Provides health check endpoints
- Runs in the `nori-cloud` namespace

## Access

- **URL**: https://guppy.norriswu.me
- **Namespace**: `nori-cloud`

## Components

### Application

- **deployment.yaml** - Main application container
- **service.yaml** - Internal networking
- **ingress.yaml** - External HTTPS access
- **secret.yaml** - Environment variables and sensitive configuration

### Automation

- **migration-hook.yaml** - Database migrations (runs before deployment)

## Deployment Process

1. **Pre-deployment**: Database migrations execute
2. **Deployment**: Application and networking resources are created

## Configuration

The application is managed through:

- Kustomize for resource organization
- Argo CD for automated deployments
- Kubernetes secrets for sensitive data
- Traefik for HTTPS termination
