FROM ubuntu:22.04

RUN apt-get update
RUN apt-get install -y build-essential curl file git

# Install Homebrew
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
ENV HOMEBREW_NO_AUTO_UPDATE=1

RUN brew tap hashicorp/tap
RUN brew install hashicorp/tap/terraform \
    awscli \
    kubectl \
    k9s
