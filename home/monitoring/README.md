# Monitoring Module

Prometheus-based monitoring stack for the Talos Kubernetes cluster.

## Components

| Component | Description |
|-----------|-------------|
| Prometheus | Metrics collection and storage (15-day retention, 50Gi storage) |
| Alertmanager | Alert routing and notifications (5Gi storage) |
| kube-state-metrics | Kubernetes object metrics |

Grafana is **not** deployed - uses external instance.

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Talos Nodes    │────▶│    Prometheus    │◀────│ kube-state-     │
│  (:9100)        │     │                  │     │ metrics         │
└─────────────────┘     └────────┬─────────┘     └─────────────────┘
                                 │
                                 ▼
                        ┌────────────────┐
                        │  Alertmanager  │
                        └────────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              ▼                  ▼                  ▼
        MetalLB LB         MetalLB LB        External Grafana
        (Prometheus)       (Alertmanager)
```

## Deployment

```bash
cd /workspace/lab/home

# Plan
tofu plan -target=module.monitoring

# Apply
tofu apply -target=module.monitoring
```

## Testing

### Check Deployment Status

```bash
# Pods
kubectl get pods -n monitoring

# Services
kubectl get svc -n monitoring
```

### Get LoadBalancer IPs

```bash
# Prometheus
kubectl get svc -n monitoring prometheus-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Alertmanager
kubectl get svc -n monitoring alertmanager-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Verify Prometheus Targets

```bash
# Port-forward to Prometheus UI
kubectl port-forward -n monitoring svc/prometheus-lb 9090:9090

# Open http://localhost:9090/targets
```

### Verify Talos Node Metrics

```bash
# From your local network
curl http://<node-ip>:9100/metrics | head -20
```

## Grafana Configuration

### Add Prometheus Data Source

1. Open Grafana → **Connections** → **Data Sources** → **Add data source**
2. Select **Prometheus**
3. Configure:
   - **Name**: `Prometheus`
   - **URL**: `http://<prometheus-lb-ip>:9090`
4. Click **Save & Test**

### Add Alertmanager Data Source

1. **Connections** → **Data Sources** → **Add data source**
2. Select **Alertmanager**
3. Configure:
   - **Name**: `Alertmanager`
   - **URL**: `http://<alertmanager-lb-ip>:9093`
   - **Implementation**: Prometheus
4. Click **Save & Test**

### Recommended Dashboards

Import from [Grafana Dashboards](https://grafana.com/grafana/dashboards/):

| ID | Name | Description |
|----|------|-------------|
| 1860 | Node Exporter Full | Host metrics (works with Talos) |
| 315 | Kubernetes cluster monitoring | Cluster overview |
| 13770 | Kubernetes All-in-One | Comprehensive K8s dashboard |

To import: **Dashboards** → **New** → **Import** → Enter ID

## Configuration

### Adjust Retention/Storage

Edit `values.yaml`:

```yaml
prometheus:
  prometheusSpec:
    retention: 15d
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 50Gi
```

### Configure Alertmanager Receivers

```yaml
alertmanager:
  config:
    route:
      receiver: 'slack'
    receivers:
      - name: 'slack'
        slack_configs:
          - api_url: 'https://hooks.slack.com/services/xxx'
            channel: '#alerts'
```

## Metrics Available

### From Talos Nodes (:9100)

- `node_cpu_seconds_total` - CPU usage
- `node_memory_*` - Memory metrics
- `node_disk_*` - Disk I/O
- `node_filesystem_*` - Filesystem usage
- `node_network_*` - Network metrics

### From kube-state-metrics

- `kube_pod_status_phase` - Pod status
- `kube_deployment_*` - Deployment metrics
- `kube_persistentvolumeclaim_*` - PVC status
- `kube_node_*` - Node conditions

### From Kubelet

- `container_cpu_*` - Container CPU
- `container_memory_*` - Container memory
- `container_network_*` - Container network

## Troubleshooting

### PVC Not Binding

```bash
kubectl get pvc -n monitoring
kubectl get storageclass
```

### Prometheus Not Scraping

Check targets at `http://<prometheus-ip>:9090/targets`

### No Data in Grafana

1. Verify data source URL
2. Check time range
3. Verify Prometheus is receiving metrics
