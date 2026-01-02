# Monitoring Stack

Prometheus-based monitoring for the Talos Kubernetes cluster.

All components are deployed to the `nori-cloud` namespace.

## Components

| Component | Description |
|-----------|-------------|
| Prometheus | Metrics collection and storage (15-day retention, 50Gi storage) |
| Alertmanager | Alert routing and notifications |
| kube-state-metrics | Kubernetes object metrics (deployments, pods, PVCs, etc.) |

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

Deployed via Argo CD ApplicationSet. The `monitoring` app deploys:
1. Argo CD Application for `kube-prometheus-stack` Helm chart
2. LoadBalancer services for external access

## Testing

### Check Deployment Status

```bash
# Argo CD applications
kubectl get applications -n argo-cd | grep -E "monitoring|kube-prometheus"

# Pods
kubectl get pods -n nori-cloud -l "app.kubernetes.io/instance=kube-prometheus-stack"

# Services
kubectl get svc -n nori-cloud | grep -E "prometheus|alertmanager"
```

### Get LoadBalancer IPs

```bash
kubectl get svc -n nori-cloud prometheus-lb alertmanager-lb
```

Example output:
```
NAME              TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)
prometheus-lb     LoadBalancer   10.96.x.x       192.168.0.15x   9090:xxxxx/TCP
alertmanager-lb   LoadBalancer   10.96.x.x       192.168.0.15x   9093:xxxxx/TCP
```

### Verify Prometheus is Scraping

```bash
# Port-forward to Prometheus UI
kubectl port-forward -n nori-cloud svc/prometheus-lb 9090:9090

# Open http://localhost:9090/targets to see scrape targets
```

### Verify Talos Node Metrics

```bash
# From your local network, curl a node's metrics endpoint
curl http://<node-ip>:9100/metrics | head -20

# Or from within the cluster
kubectl run curl --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s http://<node-ip>:9100/metrics | head -20
```

## Grafana Configuration

### Add Prometheus Data Source

1. Open Grafana → **Connections** → **Data Sources** → **Add data source**
2. Select **Prometheus**
3. Configure:
   - **Name**: `Prometheus`
   - **URL**: `http://<prometheus-lb-ip>:9090`
   - Leave authentication disabled (internal network)
4. Click **Save & Test**

### Add Alertmanager Data Source (Optional)

1. **Connections** → **Data Sources** → **Add data source**
2. Select **Alertmanager**
3. Configure:
   - **Name**: `Alertmanager`
   - **URL**: `http://<alertmanager-lb-ip>:9093`
   - **Implementation**: Prometheus
4. Click **Save & Test**

### Recommended Dashboards

Import these dashboards from [Grafana Dashboards](https://grafana.com/grafana/dashboards/):

| Dashboard ID | Name | Description |
|--------------|------|-------------|
| 1860 | Node Exporter Full | Host metrics (works with Talos metrics) |
| 315 | Kubernetes cluster monitoring | Cluster overview |
| 13770 | Kubernetes All-in-One | Comprehensive K8s dashboard |
| 6417 | Kubernetes Cluster (Prometheus) | Cluster resources |

To import: **Dashboards** → **New** → **Import** → Enter dashboard ID

## Configuration

### Helm Values

Edit `values.yaml` to customize:

```yaml
# Adjust retention
prometheus:
  prometheusSpec:
    retention: 15d      # How long to keep data
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 50Gi  # Storage size

# Configure Alertmanager routing
alertmanager:
  config:
    route:
      receiver: 'default'
    receivers:
      - name: 'default'
        # Add slack, email, etc.
```

### Adding Alertmanager Receivers

To send alerts to Slack, email, etc., update `values.yaml`:

```yaml
alertmanager:
  config:
    route:
      group_by: ['alertname', 'namespace']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
      receiver: 'slack'
    receivers:
      - name: 'slack'
        slack_configs:
          - api_url: 'https://hooks.slack.com/services/xxx/xxx/xxx'
            channel: '#alerts'
```

## Metrics Available

### From Talos Nodes (:9100)

- CPU usage (`node_cpu_seconds_total`)
- Memory (`node_memory_*`)
- Disk I/O (`node_disk_*`)
- Filesystem (`node_filesystem_*`)
- Network (`node_network_*`)

### From kube-state-metrics

- Pod status (`kube_pod_status_phase`)
- Deployment replicas (`kube_deployment_*`)
- PVC status (`kube_persistentvolumeclaim_*`)
- Node conditions (`kube_node_*`)

### From Kubelet

- Container CPU/memory (`container_cpu_*`, `container_memory_*`)
- Pod network (`container_network_*`)

## Troubleshooting

### Prometheus Not Scraping Talos Nodes

Check if nodes are reachable on port 9100:
```bash
curl http://<node-ip>:9100/metrics
```

### No Data in Grafana

1. Verify data source URL matches LoadBalancer IP
2. Check Prometheus targets: `http://<prometheus-ip>:9090/targets`
3. Verify time range in Grafana query

### PVC Not Binding

Check storage class:
```bash
kubectl get pvc -n nori-cloud
kubectl get storageclass
```
