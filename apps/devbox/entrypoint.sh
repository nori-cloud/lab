#!/bin/sh
set -eu

# Runtime dir for the privilege-separation socket.
mkdir -p /run/sshd

# Persisted host keys on the /opt PVC — generate once, reuse forever.
mkdir -p /opt/ssh
[ -f /opt/ssh/ssh_host_ed25519_key ] || ssh-keygen -q -t ed25519 -f /opt/ssh/ssh_host_ed25519_key -N ''
[ -f /opt/ssh/ssh_host_rsa_key ]     || ssh-keygen -q -t rsa -b 4096 -f /opt/ssh/ssh_host_rsa_key -N ''

# The /home/dev PVC mounts empty on first run; make sure the dev user owns it.
chown dev:dev /home/dev 2>/dev/null || true

# sshd lives at /usr/bin/sshd on Arch, /usr/sbin/sshd on Debian — resolve either.
SSHD="$(command -v sshd || echo /usr/sbin/sshd)"
exec "$SSHD" -D -e
