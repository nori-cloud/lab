FROM --platform=linux/amd64 mcr.microsoft.com/devcontainers/typescript-node:1-22-bookworm

COPY --from=ghcr.io/opentofu/opentofu:1.10.6-minimal /usr/local/bin/tofu /usr/local/bin/tofu
COPY --from=bitnami/kubectl:latest /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/kubectl

RUN wget https://github.com/derailed/k9s/releases/latest/download/k9s_linux_amd64.deb &&\
  apt install ./k9s_linux_amd64.deb &&\
  rm k9s_linux_amd64.deb

ENV UBUNTU_CODENAME=jammy
RUN wget -O- "https://keyserver.ubuntu.com/pks/lookup?fingerprint=on&op=get&search=0x6125E2A8C77F2818FB7BD15B93C4A3FD7BB9C367" | sudo gpg --dearmour -o /usr/share/keyrings/ansible-archive-keyring.gpg &&\
  echo "deb [signed-by=/usr/share/keyrings/ansible-archive-keyring.gpg] http://ppa.launchpad.net/ansible/ansible/ubuntu $UBUNTU_CODENAME main" | sudo tee /etc/apt/sources.list.d/ansible.list &&\
  sudo apt update && sudo apt install ansible -y

RUN apt-get install curl gpg apt-transport-https --yes &&\
  curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null &&\
  echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list &&\
  sudo apt-get update &&\
  sudo apt-get install helm -y

RUN wget https://github.com/digitalocean/doctl/releases/download/v1.139.0/doctl-1.139.0-linux-amd64.tar.gz &&\
  tar xf doctl-1.139.0-linux-amd64.tar.gz &&\
  mv doctl /usr/local/bin
