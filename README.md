# nori-lab

Test tenant apps for the [noperator](https://github.com/nori-cloud/noperator) operator. This repo is consumed by an Argo CD `ApplicationSet` (git directory generator over `*/overlays/{env}`), so the layout is intentionally flat — apps live at the repo root, each with `base/` and `overlays/{env}/`.

## Layout

```
network/   # gateway (kgateway) + cloudflared tunnel + secrets + TLS issuer
nginx/     # test workload, exposed via HTTPRoute
whoami/    # test workload, exposed via HTTPRoute
```

Each app follows base/overlays:

```
{app}/
  base/                 # resources shared across envs, no namespace
  overlays/{env}/       # namespace: nori-lab-{env}, patches for env-specific values
```

## Environments

- `dev`  → namespace `nori-lab-dev`
- `prod` → namespace `nori-lab-prod`

## Secret provisioning

Secrets are the tenant's responsibility. The `network` app declares a
namespaced `SecretStore` (`nori-lab-secret-store`) that authenticates to
Infisical using a `nori-lab-infisical-auth` secret. Provision that secret with
a `SealedSecret` (the `sealedSecrets` extension is enabled for this tenant):

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: nori-lab-infisical-auth
spec:
  encryptedData:
    clientId: <sealed>
    clientSecret: <sealed>
```

Then the `ExternalSecret`s in `network/` pull `/cloudflare/TUNNEL_TOKEN` and
`/cloudflare/API_TOKEN` from Infisical for the cloudflared tunnel and the
cert-manager DNS-01 solver.

## Routing

Workloads are exposed through the `nori-lab-gateway` (kgateway) `Gateway` and a
Cloudflare Tunnel (`cloudflared`), so external traffic reaches the `HTTPRoute`
hostnames without a public ingress.
