FROM --platform=linux/amd64 mcr.microsoft.com/devcontainers/typescript-node:1-22-bookworm

RUN apt-get update && apt-get install -y \
    build-essential curl git

# Install Linuxbrew as node user
USER node
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && \
    echo >> /home/node/.bashrc && \
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/node/.bashrc && \
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# https://opentofu.org/docs/intro/install/homebrew/
RUN /home/linuxbrew/.linuxbrew/bin/brew install opentofu awscli kubernetes-cli k9s

# Switch back to root for any subsequent commands
USER root
