# devbox — remote dev machine

A long-running container in the cluster to SSH into for ad-hoc development.

## Access model

- Exposed on the tailnet via a Tailscale `LoadBalancer` Service (`devbox-ssh`),
  reachable at `devbox.<tailnet>.ts.net:22`.
- **Access is gated by the tailnet ACL on `tag:devbox`** — not by an SSH
  credential. The pod's `sshd` accepts the `dev` user with an empty password;
  only tailnet identities the ACL allows can reach port 22 in the first place.
- Connect from any tailnet device the ACL permits: `ssh dev@devbox`.

### Required tailnet ACL (Tailscale admin console — not in this repo)

```jsonc
// tagOwners: let the operator proxy use the tag
"tagOwners": { "tag:devbox": ["autogroup:admin"] },

// acls: who may reach SSH
"acls": [
  { "action": "accept", "src": ["autogroup:member"], "dst": ["tag:devbox:22"] }
]
```

Revoke/rotate access by editing the `src` of that grant. No per-device keys.

## Persistence

Base image is **Arch Linux**. The `yay` AUR helper is baked in, so `yay -S <pkg>`
works at runtime.

- `/home/dev` and `/opt` are on `freenas-nfs` PVCs and survive pod restarts.
- SSH host keys are persisted under `/opt/ssh` (stable fingerprint).
- Rootfs is ephemeral: `pacman`/`yay` installs at runtime are lost on restart.
  Bake system + AUR packages you want permanent into the `Dockerfile`; install
  language toolchains into `$HOME` (mise/asdf/nix) so they persist. The yay build
  cache in `~/.cache/yay` persists on `/home`.

## Build & publish the image

No CI builds this image; use the helper script, then bump the tag in
`deployment.yaml`. Registry/image/tag are constants at the top of the script:

```bash
./build-push.sh              # build & push ghcr.io/nori-cloud/devbox:0.1.0
./build-push.sh 0.2.0        # build & push a specific tag
./build-push.sh dev --no-push  # build locally only
```

The `nori-cloud` namespace's default ServiceAccount already has the
`ghcr-credentials` image pull secret, so a private image needs no extra config.
