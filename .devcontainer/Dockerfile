FROM --platform=linux/amd64 mcr.microsoft.com/devcontainers/typescript-node:1-22-bookworm

COPY --from=ghcr.io/opentofu/opentofu:1.10.6-minimal /usr/local/bin/tofu /usr/local/bin/tofu
COPY --from=bitnami/kubectl:latest /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/kubectl

RUN curl -sS https://webinstall.dev/k9s | bash

RUN wget https://github.com/digitalocean/doctl/releases/download/v1.139.0/doctl-1.139.0-linux-amd64.tar.gz &&\
  tar xf doctl-1.139.0-linux-amd64.tar.gz &&\
  sudo mv doctl /usr/local/bin
