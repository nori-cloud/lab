# Infisical SecretStore for nori-cloud

This app configures a namespaced SecretStore for the nori-cloud namespace to pull secrets from Infisical.

## Architecture

The app uses a bootstrapping pattern:

1. **ClusterSecretStore** (in external-secrets namespace) - already configured in home infrastructure
2. **ExternalSecret** (this app) - uses ClusterSecretStore to fetch Universal Auth credentials from Infisical path `/nori-cloud/INFISICAL_MI_UA_SECRET`
3. **SecretStore** (this app) - uses the fetched credentials to authenticate to Infisical for pulling app secrets

## Configuration

- **Infisical Instance**: http://10.0.0.241
- **Project**: nori-cloud-apps-vi-m1
- **Environment**: prod
- **Secrets Path**: / (recursive)

## Usage

Apps in the nori-cloud namespace can now create ExternalSecret resources that reference the `infisical-nori-cloud` SecretStore:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-secrets
  namespace: nori-cloud
spec:
  secretStoreRef:
    name: infisical-nori-cloud
    kind: SecretStore
  target:
    name: my-app-secrets
  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: DATABASE_URL
```

## Dependencies

- External Secrets Operator (deployed via home infrastructure)
- ClusterSecretStore named "infisical" (deployed via home infrastructure)
- Infisical instance with Universal Auth configured
