# nori-lab

Test tenant apps for the [noperator](https://github.com/nori-cloud/noperator) operator. This repo is consumed by an Argo CD `ApplicationSet` (git directory generator over `*/overlays/{env}`), so the layout is intentionally flat — apps live at the repo root, each with `base/` and `overlays/{env}/`.

## Layout

```
network/          # gateway (kgateway) + cloudflared tunnel + secrets + TLS issuer (prod only)
nginx/            # test workload, HTTPRoute in prod only
whoami/           # test workload, HTTPRoute in prod only
nori-lab-secret/  # Infisical SecretStore + sealed Universal-Auth creds
```

Each app follows base/overlays:

```
{app}/
  base/                 # resources shared across envs, no namespace
  overlays/{env}/       # namespace: nori-lab-{env}, patches for env-specific values
```

## Environment

- `prod` → namespace `nori-lab-prod`

## Secret provisioning

Secrets are the tenant's responsibility. The `nori-lab-secret` app declares a
namespaced `SecretStore` (`nori-lab-secret-store`) that authenticates to
Infisical using an `infisical-universal-auth` secret. That secret is provisioned
by the `SealedSecret` in each overlay (the `sealedSecrets` extension is enabled
for this tenant).

The `ExternalSecret` in `network/` pulls `/cloudflare/TUNNEL_TOKEN` and
`/cloudflare/API_TOKEN` from Infisical for the cloudflared tunnel and the
cert-manager DNS-01 solver.

## Routing

Workloads are exposed through the `nori-lab-gateway` (kgateway) `Gateway` and a
Cloudflare Tunnel (`cloudflared`), so external traffic reaches the `HTTPRoute`
hostnames without a public ingress.
