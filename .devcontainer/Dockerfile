FROM --platform=linux/amd64 mcr.microsoft.com/devcontainers/typescript-node:1-22-bookworm

COPY --from=ghcr.io/opentofu/opentofu:minimal /usr/local/bin/tofu /usr/local/bin/tofu
COPY --from=bitnami/kubectl:latest /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/kubectl
