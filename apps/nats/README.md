# NATS JetStream

Single-instance setup. Connect via `nats://nats:4222`, monitor at `http://nats:8222`.

## Scaling to a cluster

### 1. Re-add the headless service

Create `service-headless.yaml` and add it to `kustomization.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nats-headless
  namespace: nori-cloud
  labels:
    app: nats
spec:
  type: ClusterIP
  clusterIP: None
  selector:
    app: nats
  ports:
    - port: 4222
      targetPort: 4222
      name: client
    - port: 6222
      targetPort: 6222
      name: cluster
    - port: 8222
      targetPort: 8222
      name: monitor
```

Update `statefulset.yaml`:
```yaml
spec:
  serviceName: nats-headless  # already set
```

### 2. Add cluster config to `configmap.yaml`

```
cluster {
  name: nats
  listen: 0.0.0.0:6222
  routes: [
    nats-route://nats-0.nats-headless:6222
    nats-route://nats-1.nats-headless:6222
    nats-route://nats-2.nats-headless:6222
  ]
}
```

Add `6222` to `service-headless.yaml` (already included above).

### 3. Scale up

```bash
kubectl scale statefulset nats -n nori-cloud --replicas=3
```

Or update `replicas` in `statefulset.yaml` and let Argo CD sync.
